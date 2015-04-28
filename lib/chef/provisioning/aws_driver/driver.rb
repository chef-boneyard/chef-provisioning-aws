require 'chef/mixin/shell_out'
require 'chef/provisioning/driver'
require 'chef/provisioning/convergence_strategy/install_cached'
require 'chef/provisioning/convergence_strategy/install_sh'
require 'chef/provisioning/convergence_strategy/install_msi'
require 'chef/provisioning/convergence_strategy/no_converge'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/transport/winrm'
require 'chef/provisioning/machine/windows_machine'
require 'chef/provisioning/machine/unix_machine'
require 'chef/provisioning/machine_spec'

require 'chef/resource/aws_key_pair'
require 'chef/resource/aws_instance'
require 'chef/resource/aws_image'
require 'chef/resource/aws_load_balancer'
require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/provisioning/aws_driver/version'
require 'chef/provisioning/aws_driver/credentials'

require 'yaml'
require 'aws-sdk-v1'

# loads the entire aws-sdk
AWS.eager_autoload!

class Chef
module Provisioning
module AWSDriver
  # Provisions machines using the AWS SDK
  class Driver < Chef::Provisioning::Driver

    include Chef::Mixin::ShellOut

    attr_reader :aws_config

    # URL scheme:
    # aws:profilename:region
    # TODO: migration path from fog:AWS - parse that URL
    # canonical URL calls realpath on <path>
    def self.from_url(driver_url, config)
      Driver.new(driver_url, config)
    end

    def initialize(driver_url, config)
      super

      _, profile_name, region = driver_url.split(':')
      profile_name = nil if profile_name && profile_name.empty?
      region = nil if region && region.empty?

      credentials = profile_name ? aws_credentials[profile_name] : aws_credentials.default
      @aws_config = AWS.config(
        access_key_id:     credentials[:aws_access_key_id],
        secret_access_key: credentials[:aws_secret_access_key],
        region: region || credentials[:region],
        proxy_uri: credentials[:proxy_uri] || nil,
        session_token: credentials[:aws_session_token] || nil,
        logger: Chef::Log.logger
      )
    end

    def self.canonicalize_url(driver_url, config)
      [ driver_url, config ]
    end

    # Load balancer methods
    def allocate_load_balancer(action_handler, lb_spec, lb_options, machine_specs)
      lb_options = AWSResource.lookup_options(lb_options || {}, managed_entry_store: lb_spec.managed_entry_store, driver: self)

      old_elb = nil
      actual_elb = load_balancer_for(lb_spec)
      if !actual_elb || !actual_elb.exists?
        lb_options[:listeners] ||= get_listeners(:http)
        if !lb_options[:subnets] && !lb_options[:availability_zones] && machine_specs
          lb_options[:subnets] = machine_specs.map { |s| ec2.instances[s.reference['instance_id']].subnet }.uniq
        end

        perform_action = proc { |desc, &block| action_handler.perform_action(desc, &block) }
        Chef::Log.debug "AWS Load Balancer options: #{lb_options.inspect}"

        updates = [ "create load balancer #{lb_spec.name} in #{aws_config.region}" ]
        updates << "  enable availability zones #{lb_options[:availability_zones]}" if lb_options[:availability_zones]
        updates << "  attach subnets #{lb_options[:subnets].join(', ')}" if lb_options[:subnets]
        updates << "  with listeners #{lb_options[:listeners]}" if lb_options[:listeners]
        updates << "  with security groups #{lb_options[:security_groups]}" if lb_options[:security_groups]


        action_handler.perform_action updates do
          actual_elb = elb.load_balancers.create(lb_spec.name, lb_options)

          lb_spec.reference = {
            'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
            'allocated_at' => Time.now.utc.to_s,
          }
          lb_spec.driver_url = driver_url
        end
      else
        # Header gets printed the first time we make an update
        perform_action = proc do |desc, &block|
          perform_action = proc { |desc, &block| action_handler.perform_action(desc, &block) }
          action_handler.perform_action [ "Update load balancer #{lb_spec.name} in #{aws_config.region}", desc ].flatten, &block
        end

        # TODO: refactor this whole giant method into many smaller method calls
        # TODO if we update scheme, we don't need to run any of the other updates.
        # Also, if things aren't specified (such as machines / listeners), we
        # need to grab them from the actual load balancer so we don't lose them.
        # i.e. load_balancer 'blah' do
        #   lb_options: { scheme: 'other_scheme' }
        # end
        # TODO we will leak the actual_elb if we fail to finish creating it
        # Update scheme - scheme is immutable once set, so if it is changing we need to delete the old
        # ELB and create a new one
        if lb_options[:scheme] && lb_options[:scheme].downcase != actual_elb.scheme
          desc = ["  updating scheme to #{lb_options[:scheme]}"]
          desc << "  WARN: scheme is immutable, so deleting and re-creating the ELB"
          perform_action.call(desc) do
            old_elb = actual_elb
            actual_elb = elb.load_balancers.create(lb_spec.name, lb_options)
          end
        end

        # Update security groups
        if lb_options[:security_groups]
          current = actual_elb.security_group_ids
          desired = lb_options[:security_groups]
          if current != desired
            perform_action.call("  updating security groups to #{desired.to_a}") do
              elb.client.apply_security_groups_to_load_balancer(
                load_balancer_name: actual_elb.name,
                security_groups: desired.to_a
              )
            end
          end
        end

        if lb_options[:availability_zones] || lb_options[:subnets]
          # A subnet always belongs to an availability zone.  When specifying a ELB spec, you can either
          # specify subnets OR AZs but not both.  You cannot specify multiple subnets in the same AZ.
          # You must specify at least 1 subnet or AZ.  On an update you cannot remove all subnets
          # or AZs - it must belong to one.
          if lb_options[:availability_zones] && lb_options[:subnets]
            # We do this check here because there is no atomic call we can make to specify both
            # subnets and AZs at the same time
            raise "You cannot specify both `availability_zones` and `subnets`"
          end

          # Users can switch from availability zones to subnets or vice versa.  To ensure we do not
          # unassign all (which causes an AWS error) we first add all available ones, then remove
          # an unecessary ones
          actual_zones_subnets = {}
          actual_elb.subnets.each do |subnet|
            actual_zones_subnets[subnet.id] = subnet.availability_zone.name
          end

          # Only 1 of subnet or AZ will be populated b/c of our check earlier
          desired_subnets_zones = {}
          if lb_options[:availability_zones]
            lb_options[:availability_zones].each do |zone|
              # If the user specifies availability zone, we find the default subnet for that
              # AZ because this duplicates the create logic
              zone = zone.downcase
              filters = [
                {:name => 'availabilityZone', :values => [zone]},
                {:name => 'defaultForAz', :values => ['true']}
              ]
              default_subnet = ec2.client.describe_subnets(:filters => filters)[:subnet_set]
              if default_subnet.size != 1
                raise "Could not find default subnet in availability zone #{zone}"
              end
              default_subnet = default_subnet[0]
              desired_subnets_zones[default_subnet[:subnet_id]] = zone
            end
          end
          unless lb_options[:subnets].nil? || lb_options[:subnets].empty?
            subnet_query = ec2.client.describe_subnets(:subnet_ids => lb_options[:subnets])[:subnet_set]
            # AWS raises an error on an unknown subnet, but not an unknown AZ
            subnet_query.each do |subnet|
              zone = subnet[:availability_zone].downcase
              desired_subnets_zones[subnet[:subnet_id]] = zone
            end
          end

          # We only bother attaching subnets, because doing this automatically attaches the AZ
          attach_subnets = desired_subnets_zones.keys - actual_zones_subnets.keys
          unless attach_subnets.empty?
            action = "  attach subnets #{attach_subnets.join(', ')}"
            enable_zones = (desired_subnets_zones.map {|s,z| z if attach_subnets.include?(s)}).compact
            action += " (availability zones #{enable_zones.join(', ')})"
            perform_action.call(action) do
              begin
                elb.client.attach_load_balancer_to_subnets(
                  load_balancer_name: actual_elb.name,
                  subnets: attach_subnets
                )
              rescue AWS::ELB::Errors::InvalidConfigurationRequest
                raise "You cannot currently move from 1 subnet to another in the same availability zone. " +
                    "Amazon does not have an atomic operation which allows this.  You must create a new " +
                    "ELB with the correct subnets and move instances into it.  Tried to attach subets " +
                    "#{attach_subnets.join(', ')} (availability zones #{enable_zones.join(', ')}) to " +
                    "existing ELB named #{actual_elb.name}"
              end
            end
          end

          detach_subnets = actual_zones_subnets.keys - desired_subnets_zones.keys
          unless detach_subnets.empty?
            action = "  detach subnets #{detach_subnets.join(', ')}"
            disable_zones = (actual_zones_subnets.map {|s,z| z if detach_subnets.include?(s)}).compact
            action += " (availability zones #{disable_zones.join(', ')})"
            perform_action.call(action) do
              elb.client.detach_load_balancer_from_subnets(
                load_balancer_name: actual_elb.name,
                subnets: detach_subnets
              )
            end
          end
        end

        # Update listeners - THIS IS NOT ATOMIC
        if lb_options[:listeners]
          add_listeners = {}
          lb_options[:listeners].each { |l| add_listeners[l[:port]] = l }
          actual_elb.listeners.each do |listener|
            desired_listener = add_listeners.delete(listener.port)
            if desired_listener

              # listener.(port|protocol|instance_port|instance_protocol) are immutable for the life
              # of the listener - must create a new one and delete old one
              immutable_updates = []
              if listener.protocol != desired_listener[:protocol].to_sym.downcase
                immutable_updates << "    update protocol from #{listener.protocol.inspect} to #{desired_listener[:protocol].inspect}"
              end
              if listener.instance_port != desired_listener[:instance_port]
                immutable_updates << "    update instance port from #{listener.instance_port.inspect} to #{desired_listener[:instance_port].inspect}"
              end
              if listener.instance_protocol != desired_listener[:instance_protocol].to_sym.downcase
                immutable_updates << "    update instance protocol from #{listener.instance_protocol.inspect} to #{desired_listener[:instance_protocol].inspect}"
              end
              if !immutable_updates.empty?
                perform_action.call(immutable_updates) do
                  listener.delete
                  actual_elb.listeners.create(desired_listener)
                end
              elsif listener.server_certificate != desired_listener[:server_certificate]
                # Server certificate is mutable - if no immutable changes required a full recreate, update cert
                perform_action.call("    update server certificate from #{listener.server_certificate} to #{desired_listener[:server_certificate]}") do
                  listener.server_certificate = desired_listener[:server_certificate]
                end
              end

            else
              perform_action.call("  remove listener #{listener.port}") do
                listener.delete
              end
            end
          end
          add_listeners.values.each do |listener|
            updates = [ "  add listener #{listener[:port]}" ]
            updates << "    set protocol to #{listener[:protocol].inspect}"
            updates << "    set instance port to #{listener[:instance_port].inspect}"
            updates << "    set instance protocol to #{listener[:instance_protocol].inspect}"
            updates << "    set server certificate to #{listener[:server_certificate]}" if listener[:server_certificate]
            perform_action.call(updates) do
              actual_elb.listeners.create(listener)
            end
          end
        end
      end

      # Update instance list, but only if there are machines specified
      if machine_specs
        actual_instance_ids = actual_elb.instances.map { |i| i.instance_id }

        instances_to_add = machine_specs.select { |s| !actual_instance_ids.include?(s.reference['instance_id']) }
        instance_ids_to_remove = actual_instance_ids - machine_specs.map { |s| s.reference['instance_id'] }

        if instances_to_add.size > 0
          perform_action.call("  add machines #{instances_to_add.map { |s| s.name }.join(', ')}") do
            instance_ids_to_add = instances_to_add.map { |s| s.reference['instance_id'] }
            Chef::Log.debug("Adding instances #{instance_ids_to_add.join(', ')} to load balancer #{actual_elb.name} in region #{aws_config.region}")
            actual_elb.instances.add(instance_ids_to_add)
          end
        end

        if instance_ids_to_remove.size > 0
          perform_action.call("  remove instances #{instance_ids_to_remove}") do
            actual_elb.instances.remove(instance_ids_to_remove)
          end
        end
      end

      # We have successfully switched all our instances to the (possibly) new LB
      # so it is safe to delete the old one.
      unless old_elb.nil?
        old_elb.delete
      end
    ensure
      # Something went wrong before we could moved instances from the old ELB to the new one
      # Don't delete the old ELB, but warn users there could now be 2 ELBs with the same name
      unless old_elb.nil?
        Chef::Log.warn("It is possible there are now 2 ELB instances - #{old_elb.name} and #{actual_elb.name}. " +
        "Determine which is correct and manually clean up the other.")
      end
    end

    def ready_load_balancer(action_handler, lb_spec, lb_options, machine_spec)
    end

    def destroy_load_balancer(action_handler, lb_spec, lb_options)
      return if lb_spec == nil

      actual_elb = load_balancer_for(lb_spec)
      if actual_elb && actual_elb.exists?
        # Remove ELB from AWS
        action_handler.perform_action "Deleting EC2 ELB #{lb_spec.id}" do
          actual_elb.delete
        end
      end

      # Remove LB spec from databag
      lb_spec.delete(action_handler)
    end

    # Image methods
    def allocate_image(action_handler, image_spec, image_options, machine_spec, machine_options)
      actual_image = image_for(image_spec)
      if actual_image.nil? || !actual_image.exists? || actual_image.state == :failed
        action_handler.perform_action "Create image #{image_spec.name} from machine #{machine_spec.name} with options #{image_options.inspect}" do
          image_options[:name] ||= image_spec.name
          image_options[:instance_id] ||= machine_spec.reference['instance_id']
          image_options[:description] ||= "Image #{image_spec.name} created from machine #{machine_spec.name}"
          Chef::Log.debug "AWS Image options: #{image_options.inspect}"
          image = ec2.images.create(image_options.to_hash)
          image.add_tag('From-Instance', :value => image_options[:instance_id]) if image_options[:instance_id]
          image_spec.reference = {
            'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
            'image_id' => image.id,
            'allocated_at' => Time.now.to_i
          }
          image_spec.driver_url = driver_url
        end
      end
    end

    def ready_image(action_handler, image_spec, image_options)
      actual_image = image_for(image_spec)
      if actual_image.nil? || !actual_image.exists?
        raise 'Cannot ready an image that does not exist'
      else
        if actual_image.state != :available
          action_handler.report_progress 'Waiting for image to be ready ...'
          wait_until_ready_image(action_handler, image_spec, actual_image)
        else
          action_handler.report_progress "Image #{image_spec.name} is ready!"
        end
      end
    end

    def destroy_image(action_handler, image_spec, image_options)
      # TODO the driver should automatically be set by `inline_resource`
      d = self
      Provisioning.inline_resource(action_handler) do
        aws_image image_spec.name do
          action :destroy
          driver d
        end
      end
    end

    def user_data
      # TODO: Make this use HTTPS at some point.
      <<EOD
<powershell>
winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="300"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow
netsh advfirewall firewall add rule name="WinRM 5986" protocol=TCP dir=in localport=5986 action=allow

net stop winrm
sc config winrm start=auto
net start winrm
</powershell>
EOD
    end

    # Machine methods
    def allocate_machine(action_handler, machine_spec, machine_options)
      actual_instance = instance_for(machine_spec)
      if actual_instance == nil || !actual_instance.exists? || actual_instance.status == :terminated
        bootstrap_options = bootstrap_options_for(action_handler, machine_spec, machine_options)

        action_handler.perform_action "Create #{machine_spec.name} with AMI #{bootstrap_options[:image_id]} in #{aws_config.region}" do
          Chef::Log.debug "Creating instance with bootstrap options #{bootstrap_options}"

          instance = ec2.instances.create(bootstrap_options.to_hash)

          # Make sure the instance is ready to be tagged
          sleep 5 while instance.status == :pending
          # TODO add other tags identifying user / node url (same as fog)
          instance.tags['Name'] = machine_spec.name
          instance.source_dest_check = machine_options[:source_dest_check] if machine_options.has_key?(:source_dest_check)
          machine_spec.reference = {
              'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
              'allocated_at' => Time.now.utc.to_s,
              'host_node' => action_handler.host_node,
              'image_id' => bootstrap_options[:image_id],
              'instance_id' => instance.id
          }
          machine_spec.driver_url = driver_url
          machine_spec.reference['key_name'] = bootstrap_options[:key_name] if bootstrap_options[:key_name]
          %w(is_windows ssh_username sudo use_private_ip_for_ssh ssh_gateway).each do |key|
            machine_spec.reference[key] = machine_options[key.to_sym] if machine_options[key.to_sym]
          end
        end
      end
    end

    def allocate_machines(action_handler, specs_and_options, parallelizer)
      create_servers(action_handler, specs_and_options, parallelizer) do |machine_spec, server|
        yield machine_spec
      end
      specs_and_options.keys
    end

    def ready_machine(action_handler, machine_spec, machine_options)
      instance = instance_for(machine_spec)

      if instance.nil?
        raise "Machine #{machine_spec.name} does not have an instance associated with it, or instance does not exist."
      end

      if instance.status != :running
        wait_until_machine(action_handler, machine_spec, instance) { instance.status != :stopping }
        if instance.status == :stopped
          action_handler.perform_action "Start #{machine_spec.name} (#{machine_spec.reference['instance_id']}) in #{aws_config.region} ..." do
            instance.start
          end
        end
        wait_until_ready_machine(action_handler, machine_spec, instance)
      end

      wait_for_transport(action_handler, machine_spec, machine_options)
      machine_for(machine_spec, machine_options, instance)
    end

    def connect_to_machine(name, chef_server = nil)
      if name.is_a?(MachineSpec)
        machine_spec = name
      else
        machine_spec = Chef::Provisioning::ChefMachineSpec.get(name, chef_server)
      end

      machine_for(machine_spec, machine_spec.reference)
    end

    def destroy_machine(action_handler, machine_spec, machine_options)
      d = self
      Provisioning.inline_resource(action_handler) do
        aws_instance machine_spec.name do
          action :destroy
          driver d
        end
      end

      # TODO move this into the aws_instance provider somehow
      strategy = convergence_strategy_for(machine_spec, machine_options)
      strategy.cleanup_convergence(action_handler, machine_spec)
    end

    def ec2
      @ec2 ||= AWS::EC2.new(config: aws_config)
    end

    def elb
      @elb ||= AWS::ELB.new(config: aws_config)
    end

    def iam
      @iam ||= AWS::IAM.new(config: aws_config)
    end

    def s3
      @s3 ||= AWS::S3.new(config: aws_config)
    end

    def sns
      @sns ||= AWS::SNS.new(config: aws_config)
    end

    def sqs
      @sqs ||= AWS::SQS.new(config: aws_config)
    end

    def auto_scaling
      @auto_scaling ||= AWS::AutoScaling.new(config: aws_config)
    end

    def build_arn(partition: 'aws', service: nil, region: aws_config.region, account_id: self.account_id, resource: nil)
      "arn:#{partition}:#{service}:#{region}:#{account_id}:#{resource}"
    end

    def parse_arn(arn)
      parts = arn.split(':', 6)
      {
        partition: parts[1],
        service: parts[2],
        region: parts[3],
        account_id: parts[4],
        resource: parts[5]
      }
    end

    def account_id
      begin
        # We've got an AWS account root credential or an IAM admin with access rights
        current_user = iam.client.get_user
        arn = current_user[:user][:arn]
      rescue AWS::IAM::Errors::AccessDenied => e
        # If we don't have access, the error message still tells us our account ID and user ...
        # https://forums.aws.amazon.com/thread.jspa?messageID=394344
        if e.to_s !~ /\b(arn:aws:iam::[0-9]{12}:\S*)/
          raise "IAM error response for GetUser did not include user ARN.  Can't retrieve account ID."
        end
        arn = $1
      end
      parse_arn(arn)[:account_id]
    end

    # For creating things like AWS keypairs exclusively
    @@chef_default_lock = Mutex.new

    def machine_for(machine_spec, machine_options, instance = nil)
      instance ||= instance_for(machine_spec)

      if !instance
        raise "Instance for node #{machine_spec.name} has not been created!"
      end

      if machine_spec.reference['is_windows']
        Chef::Provisioning::Machine::WindowsMachine.new(machine_spec, transport_for(machine_spec, machine_options, instance), convergence_strategy_for(machine_spec, machine_options))
      else
        Chef::Provisioning::Machine::UnixMachine.new(machine_spec, transport_for(machine_spec, machine_options, instance), convergence_strategy_for(machine_spec, machine_options))
      end
    end

    def bootstrap_options_for(action_handler, machine_spec, machine_options)
      bootstrap_options = (machine_options[:bootstrap_options] || {}).to_h.dup
      bootstrap_options[:instance_type] ||= default_instance_type
      image_id = bootstrap_options[:image_id] || machine_options[:image_id] || default_ami_for_region(aws_config.region)
      bootstrap_options[:image_id] = image_id
      if !bootstrap_options[:key_name]
        Chef::Log.debug('No key specified, generating a default one...')
        bootstrap_options[:key_name] = default_aws_keypair(action_handler, machine_spec)
      end

      if machine_options[:is_windows]
        Chef::Log.debug "Setting WinRM userdata..."
        bootstrap_options[:user_data] = user_data
      else
        Chef::Log.debug "Non-windows, not setting userdata"
      end

      bootstrap_options = AWSResource.lookup_options(bootstrap_options, managed_entry_store: machine_spec.managed_entry_store, driver: self)
      Chef::Log.debug "AWS Bootstrap options: #{bootstrap_options.inspect}"
      bootstrap_options
    end

    def default_ssh_username
      'ubuntu'
    end

    def keypair_for(bootstrap_options)
      if bootstrap_options[:key_name]
        keypair_name = bootstrap_options[:key_name]
        actual_key_pair = ec2.key_pairs[keypair_name]
        if !actual_key_pair.exists?
          ec2.key_pairs.create(keypair_name)
        end
        actual_key_pair
      end
    end

    def load_balancer_for(lb_spec)
      Chef::Resource::AwsLoadBalancer.get_aws_object(lb_spec.name, driver: self, managed_entry_store: lb_spec.managed_entry_store, required: false)
    end

    def instance_for(machine_spec)
      if machine_spec.reference
        if machine_spec.driver_url != driver_url
          raise "Switching a machine's driver from #{machine_spec.driver_url} to #{driver_url} is not currently supported!  Use machine :destroy and then re-create the machine on the new driver."
        end
        Chef::Resource::AwsInstance.get_aws_object(machine_spec.reference['instance_id'], driver: self, managed_entry_store: machine_spec.managed_entry_store, required: false)
      end
    end

    def instances_for(machine_specs)
      result = {}
      machine_specs.each { |machine_spec| result[machine_spec] = instance_for(machine_spec) }
      result
    end

    def image_for(image_spec)
      Chef::Resource::AwsImage.get_aws_object(image_spec.name, driver: self, managed_entry_store: image_spec.managed_entry_store, required: false)
    end

    def transport_for(machine_spec, machine_options, instance)
      if machine_spec.reference['is_windows']
        create_winrm_transport(machine_spec, machine_options, instance)
      else
        create_ssh_transport(machine_spec, machine_options, instance)
      end
    end

    def aws_credentials
      # Grab the list of possible credentials
      @aws_credentials ||= if driver_options[:aws_credentials]
                             driver_options[:aws_credentials]
                           else
                             credentials = Credentials.new
                             if driver_options[:aws_config_file]
                               credentials.load_ini(driver_options[:aws_config_file])
                             elsif driver_options[:aws_csv_file]
                               credentials.load_csv(driver_options[:aws_csv_file])
                             else
                               credentials.load_default
                             end
                             credentials
                           end
    end

    def default_ami_for_region(region)
      Chef::Log.debug("Choosing default AMI for region '#{region}'")

      case region
        when 'ap-northeast-1'
          'ami-6cbca76d'
        when 'ap-southeast-1'
          'ami-04c6ec56'
        when 'ap-southeast-2'
          'ami-c9eb9ff3'
        when 'eu-west-1'
          'ami-5f9e1028'
        when 'eu-central-1'
          'ami-56c2f14b'
        when 'sa-east-1'
          'ami-81f14e9c'
        when 'us-east-1'
          'ami-12793a7a'
        when 'us-west-1'
          'ami-6ebca42b'
        when 'us-west-2'
          'ami-b9471c89'
        else
          raise 'Unsupported region!'
      end
    end

    def create_winrm_transport(machine_spec, machine_options, instance)
      remote_host = determine_remote_host(machine_spec, instance)

      port = machine_spec.reference['winrm_port'] || 5985
      endpoint = "http://#{remote_host}:#{port}/wsman"
      type = :plaintext
      pem_bytes = get_private_key(instance.key_name)
      encrypted_admin_password = wait_for_admin_password(machine_spec)

      decoded = Base64.decode64(encrypted_admin_password)
      private_key = OpenSSL::PKey::RSA.new(pem_bytes)
      decrypted_password = private_key.private_decrypt decoded

      winrm_options = {
        :user => machine_spec.reference['winrm_username'] || 'Administrator',
        :pass => decrypted_password,
        :disable_sspi => true,
        :basic_auth_only => true
      }

      Chef::Provisioning::Transport::WinRM.new("#{endpoint}", type, winrm_options, {})
    end

    def wait_for_admin_password(machine_spec)
      time_elapsed = 0
      sleep_time = 10
      max_wait_time = 900 # 15 minutes
      encrypted_admin_password = nil
      instance_id = machine_spec.reference['instance_id']

      Chef::Log.info "waiting for #{machine_spec.name}'s admin password to be available..."
      while time_elapsed < max_wait_time && encrypted_admin_password.nil?
        response = ec2.client.get_password_data({ :instance_id => instance_id })
        encrypted_admin_password = response['password_data'.to_sym]

        if encrypted_admin_password.nil?
          Chef::Log.info "#{time_elapsed}/#{max_wait_time}s elapsed -- sleeping #{sleep_time} for #{machine_spec.name}'s admin password."
          sleep(sleep_time)
          time_elapsed += sleep_time
        end
      end

      Chef::Log.info "#{machine_spec.name}'s admin password is available!"

      encrypted_admin_password
    end

    def create_ssh_transport(machine_spec, machine_options, instance)
      ssh_options = ssh_options_for(machine_spec, machine_options, instance)
      username = machine_spec.reference['ssh_username'] || machine_options[:ssh_username] || default_ssh_username
      if machine_options.has_key?(:ssh_username) && machine_options[:ssh_username] != machine_spec.reference['ssh_username']
        Chef::Log.warn("Server #{machine_spec.name} was created with SSH username #{machine_spec.reference['ssh_username']} and machine_options specifies username #{machine_options[:ssh_username]}.  Using #{machine_spec.reference['ssh_username']}.  Please edit the node and change the chef_provisioning.reference.ssh_username attribute if you want to change it.")
      end
      options = {}
      if machine_spec.reference[:sudo] || (!machine_spec.reference.has_key?(:sudo) && username != 'root')
        options[:prefix] = 'sudo '
      end

      remote_host = determine_remote_host(machine_spec, instance)

      #Enable pty by default
      options[:ssh_pty_enable] = true
      options[:ssh_gateway] = machine_spec.reference['ssh_gateway'] if machine_spec.reference.has_key?('ssh_gateway')

      Chef::Provisioning::Transport::SSH.new(remote_host, username, ssh_options, options, config)
    end

    def determine_remote_host(machine_spec, instance)
      if machine_spec.reference['use_private_ip_for_ssh']
        instance.private_ip_address
      elsif !instance.public_ip_address
        Chef::Log.warn("Server #{machine_spec.name} has no public ip address.  Using private ip '#{instance.private_ip_address}'.  Set driver option 'use_private_ip_for_ssh' => true if this will always be the case ...")
        instance.private_ip_address
      elsif instance.public_ip_address
        instance.public_ip_address
      else
        raise "Server #{instance.id} has no private or public IP address!"
      end
    end

    def ssh_options_for(machine_spec, machine_options, instance)
      result = {
        # TODO create a user known hosts file
        #          :user_known_hosts_file => vagrant_ssh_config['UserKnownHostsFile'],
        #          :paranoid => true,
        :auth_methods => [ 'publickey' ],
        :keys_only => true,
        :host_key_alias => "#{instance.id}.AWS"
      }.merge(machine_options[:ssh_options] || {})
      if instance.respond_to?(:private_key) && instance.private_key
        result[:key_data] = [ instance.private_key ]
      elsif instance.respond_to?(:key_name) && instance.key_name
        key = get_private_key(instance.key_name)
        unless key
          raise "Server has key name '#{instance.key_name}', but the corresponding private key was not found locally.  Check if the key is in Chef::Config.private_key_paths: #{Chef::Config.private_key_paths.join(', ')}"
        end
        result[:key_data] = [ key ]
      elsif machine_spec.reference['key_name']
        key = get_private_key(machine_spec.reference['key_name'])
        unless key
          raise "Server was created with key name '#{machine_spec.reference['key_name']}', but the corresponding private key was not found locally.  Check if the key is in Chef::Config.private_key_paths: #{Chef::Config.private_key_paths.join(', ')}"
        end
        result[:key_data] = [ key ]
      elsif machine_options[:bootstrap_options] && machine_options[:bootstrap_options][:key_path]
        result[:key_data] = [ IO.read(machine_options[:bootstrap_options][:key_path]) ]
      elsif machine_options[:bootstrap_options] && machine_options[:bootstrap_options][:key_name]
        result[:key_data] = [ get_private_key(machine_options[:bootstrap_options][:key_name]) ]
      else
        # TODO make a way to suggest other keys to try ...
        raise "No key found to connect to #{machine_spec.name} (#{machine_spec.reference.inspect})!"
      end
      result
    end

    def convergence_strategy_for(machine_spec, machine_options)
      # Tell Ohai that this is an EC2 instance so that it runs the EC2 plugin
      convergence_options = Cheffish::MergedConfig.new(
        machine_options[:convergence_options] || {},
        ohai_hints: { 'ec2' => '' })

      # Defaults
      if !machine_spec.reference
        return Chef::Provisioning::ConvergenceStrategy::NoConverge.new(convergence_options, config)
      end

      if machine_spec.reference['is_windows']
        Chef::Provisioning::ConvergenceStrategy::InstallMsi.new(convergence_options, config)
      elsif machine_options[:cached_installer] == true
        Chef::Provisioning::ConvergenceStrategy::InstallCached.new(convergence_options, config)
      else
        Chef::Provisioning::ConvergenceStrategy::InstallSh.new(convergence_options, config)
      end
    end

    def wait_until_ready_image(action_handler, image_spec, image=nil)
      wait_until_image(action_handler, image_spec, image) { image.state == :available }
    end

    def wait_until_image(action_handler, image_spec, image=nil, &block)
      image ||= image_for(image_spec)
      time_elapsed = 0
      sleep_time = 10
      max_wait_time = 300
      if !yield(image)
        action_handler.report_progress "waiting for #{image_spec.name} (#{image.id} on #{driver_url}) to be ready ..."
        while time_elapsed < max_wait_time && !yield(image)
          action_handler.report_progress "been waiting #{time_elapsed}/#{max_wait_time} -- sleeping #{sleep_time} seconds for #{image_spec.name} (#{image.id} on #{driver_url}) to be ready ..."
          sleep(sleep_time)
          time_elapsed += sleep_time
        end
        unless yield(image)
          raise "Image #{image.id} did not become ready within #{max_wait_time} seconds"
        end
        action_handler.report_progress "Image #{image_spec.name} is now ready"
      end
    end

    def wait_until_ready_machine(action_handler, machine_spec, instance=nil)
      wait_until_machine(action_handler, machine_spec, instance) { instance.status == :running }
    end

    def wait_until_machine(action_handler, machine_spec, instance=nil, &block)
      instance ||= instance_for(machine_spec)
      time_elapsed = 0
      sleep_time = 10
      max_wait_time = 120
      if !yield(instance)
        if action_handler.should_perform_actions
          action_handler.report_progress "waiting for #{machine_spec.name} (#{instance.id} on #{driver_url}) to be ready ..."
          while time_elapsed < max_wait_time && !yield(instance)
            action_handler.report_progress "been waiting #{time_elapsed}/#{max_wait_time} -- sleeping #{sleep_time} seconds for #{machine_spec.name} (#{instance.id} on #{driver_url}) to be ready ..."
            sleep(sleep_time)
            time_elapsed += sleep_time
          end
          unless yield(instance)
            raise "Image #{instance.id} did not become ready within #{max_wait_time} seconds"
          end
          action_handler.report_progress "#{machine_spec.name} is now ready"
        end
      end
    end

    def wait_for_transport(action_handler, machine_spec, machine_options)
      instance = instance_for(machine_spec)
      time_elapsed = 0
      sleep_time = 10
      max_wait_time = 120
      transport = transport_for(machine_spec, machine_options, instance)
      unless transport.available?
        if action_handler.should_perform_actions
          action_handler.report_progress "waiting for #{machine_spec.name} (#{instance.id} on #{driver_url}) to be connectable (transport up and running) ..."
          while time_elapsed < max_wait_time && !transport.available?
            action_handler.report_progress "been waiting #{time_elapsed}/#{max_wait_time} -- sleeping #{sleep_time} seconds for #{machine_spec.name} (#{instance.id} on #{driver_url}) to be connectable ..."
            sleep(sleep_time)
            time_elapsed += sleep_time
          end

          action_handler.report_progress "#{machine_spec.name} is now connectable"
        end
      end
    end

    def default_aws_keypair_name(machine_spec)
      if machine_spec.reference &&
          Gem::Version.new(machine_spec.reference['driver_version']) < Gem::Version.new('0.10')
        'metal_default'
      else
        'chef_default'
      end
    end

    def default_aws_keypair(action_handler, machine_spec)
      driver = self
      default_key_name = default_aws_keypair_name(machine_spec)
      updated = @@chef_default_lock.synchronize do
        Provisioning.inline_resource(action_handler) do
          aws_key_pair default_key_name do
            driver driver
            allow_overwrite true
          end
        end
      end

      # Only warn the first time
      default_warning = 'Using default key, which is not shared between machines!  It is recommended to create an AWS key pair with the aws_key_pair resource, and set :bootstrap_options => { :key_name => <key name> }'
      Chef::Log.warn(default_warning) if updated

      default_key_name
    end

    def create_servers(action_handler, specs_and_options, parallelizer, &block)
      specs_and_servers = instances_for(specs_and_options.keys)

      by_bootstrap_options = {}
      specs_and_options.each do |machine_spec, machine_options|
        actual_instance = specs_and_servers[machine_spec]
        if actual_instance
          if actual_instance.status == :terminated
            Chef::Log.warn "Machine #{machine_spec.name} (#{actual_instance.id}) is terminated.  Recreating ..."
          else
            yield machine_spec, actual_instance if block_given?
            next
          end
        elsif machine_spec.reference
          Chef::Log.warn "Machine #{machine_spec.name} (#{machine_spec.reference['instance_id']} on #{driver_url}) no longer exists.  Recreating ..."
        end

        bootstrap_options = bootstrap_options_for(action_handler, machine_spec, machine_options)
        by_bootstrap_options[bootstrap_options] ||= []
        by_bootstrap_options[bootstrap_options] << machine_spec
      end

      # Create the servers in parallel
      parallelizer.parallelize(by_bootstrap_options) do |bootstrap_options, machine_specs|
        machine_description = if machine_specs.size == 1
          "machine #{machine_specs.first.name}"
        else
          "machines #{machine_specs.map { |s| s.name }.join(", ")}"
        end
        description = [ "creating #{machine_description} on #{driver_url}" ]
        bootstrap_options.each_pair { |key,value| description << "  #{key}: #{value.inspect}" }
        action_handler.report_progress description
        if action_handler.should_perform_actions
          # Actually create the servers
          create_many_instances(machine_specs.size, bootstrap_options, parallelizer) do |instance|

            # Assign each one to a machine spec
            machine_spec = machine_specs.pop
            machine_options = specs_and_options[machine_spec]
            machine_spec.reference = {
              'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
              'allocated_at' => Time.now.utc.to_s,
              'host_node' => action_handler.host_node,
              'image_id' => bootstrap_options[:image_id],
              'instance_id' => instance.id
            }
            machine_spec.driver_url = driver_url
            instance.tags['Name'] = machine_spec.name
            instance.source_dest_check = machine_options[:source_dest_check] if machine_options.has_key?(:source_dest_check)
            machine_spec.reference['key_name'] = bootstrap_options[:key_name] if bootstrap_options[:key_name]
            %w(is_windows ssh_username sudo use_private_ip_for_ssh ssh_gateway).each do |key|
              machine_spec.reference[key] = machine_options[key.to_sym] if machine_options[key.to_sym]
            end
            action_handler.performed_action "machine #{machine_spec.name} created as #{instance.id} on #{driver_url}"

            yield machine_spec, instance if block_given?
          end

          if machine_specs.size > 0
            raise "Not all machines were created by create_servers"
          end
        end
      end.to_a
    end

    def create_many_instances(num_servers, bootstrap_options, parallelizer)
      parallelizer.parallelize(1.upto(num_servers)) do |i|
        clean_bootstrap_options = Marshal.load(Marshal.dump(bootstrap_options))
        instance = ec2.instances.create(clean_bootstrap_options.to_hash)

        yield instance if block_given?
        instance
      end.to_a
    end

    def get_listeners(listeners)
      case listeners
      when Hash
        listeners.map do |from, to|
          from = get_listener(from)
          from.delete(:instance_port)
          from.delete(:instance_protocol)
          to = get_listener(to)
          to.delete(:port)
          to.delete(:protocol)
          to.merge(from)
        end
      when Array
        listeners.map { |listener| get_listener(listener) }
      when nil
        nil
      else
        [ get_listener(listeners) ]
      end
    end

    def get_listener(listener)
      result = {}

      case listener
      when Hash
        result.merge!(listener)
      when Array
        result[:port] = listener[0] if listener.size >= 1
        result[:protocol] = listener[1] if listener.size >= 2
      when Symbol,String
        result[:protocol] = listener
      when Integer
        result[:port] = listener
      else
        raise "Invalid listener #{listener}"
      end

      # If either port or protocol are set, set the other
      if result[:port] && !result[:protocol]
        result[:protocol] = PROTOCOL_DEFAULTS[result[:port]]
      elsif result[:protocol] && !result[:port]
        result[:port] = PORT_DEFAULTS[result[:protocol]]
      end
      if result[:instance_port] && !result[:instance_protocol]
        result[:instance_protocol] = PROTOCOL_DEFAULTS[result[:instance_port]]
      elsif result[:instance_protocol] && !result[:instance_port]
        result[:instance_port] = PORT_DEFAULTS[result[:instance_protocol]]
      end

      # If instance_port is still unset, copy port/protocol over
      result[:instance_port] ||= result[:port]
      result[:instance_protocol] ||= result[:protocol]

      result
    end

    def default_instance_type
      't2.micro'
    end

    PORT_DEFAULTS = {
      :http => 80,
      :https => 443,
    }
    PROTOCOL_DEFAULTS = {
      25 => :tcp,
      80 => :http,
      443 => :https,
      465 => :ssl,
      587 => :tcp,
    }

  end
end
end
end

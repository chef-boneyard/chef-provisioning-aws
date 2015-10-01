#require 'byebug'
require 'pry'
require 'pry-byebug'
require 'chef/mixin/shell_out'
require 'chef/mixin/deep_merge'
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

require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/provisioning/aws_driver/tagging_strategy/ec2'
require 'chef/provisioning/aws_driver/tagging_strategy/elb'
require 'chef/provisioning/aws_driver/version'
require 'chef/provisioning/aws_driver/credentials'
require 'chef/provisioning/aws_driver/credentials2'
require 'chef/provisioning/aws_driver/aws_tagger'

require 'yaml'
require 'aws-sdk-v1'
require 'aws-sdk'
require 'retryable'
require 'ubuntu_ami'
require 'base64'

# loads the entire aws-sdk
AWS.eager_autoload!
AWS_V2_SERVICES = {
  "EC2" => "ec2",
  "Route53" => "route53",
  "S3" => "s3",
  "ElasticLoadBalancing" => "elb",
  "IAM" => "iam",
}
Aws.eager_autoload!(:services => AWS_V2_SERVICES.keys)

# Need to load the resources after the SDK because `aws_sdk_types` can mess
# up AWS loading if they are loaded too early
require 'chef/resource/aws_key_pair'
require 'chef/resource/aws_instance'
require 'chef/resource/aws_image'
require 'chef/resource/aws_load_balancer'

# We add the appropriate attributes to the base resources for tagging support
class Chef
class Resource
  class Machine
    include Chef::Provisioning::AWSDriver::AWSTaggable
  end
  class MachineImage
    include Chef::Provisioning::AWSDriver::AWSTaggable
  end
  class LoadBalancer
    include Chef::Provisioning::AWSDriver::AWSTaggable
  end
end
end

require 'chef/provider/load_balancer'
class Chef
class Provider
  class LoadBalancer
    # We override this so we can specify a machine name as `i-123456`
    # This is totally a hack until we move away from base resources
    def get_machine_spec!(machine_name)
      if machine_name =~ /^i-[a-f0-9]{8}$/
        Struct.new(:name, :reference).new(machine_name, {'instance_id' => machine_name})
      else
        Chef::Log.debug "Getting machine spec for #{machine_name}"
        Provisioning.chef_managed_entry_store(new_resource.chef_server).get!(:machine, machine_name)
      end
    end
  end
end
end

Chef::Provider::Machine.additional_machine_option_keys << :aws_tags
Chef::Provider::MachineImage.additional_image_option_keys << :aws_tags
Chef::Provider::LoadBalancer.additional_lb_option_keys << :aws_tags

class Chef
module Provisioning
module AWSDriver
  # Provisions machines using the AWS SDK
  class Driver < Chef::Provisioning::Driver

    include Chef::Mixin::ShellOut
    include Chef::Mixin::DeepMerge

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

      # TODO document how users could add something to the Aws.config themselves if they want to
      # Right now we are supporting both V1 and V2, so we create 2 config sets
      credentials2 = Credentials2.new(:profile_name => profile_name)
      Chef::Config.chef_provisioning ||= {}
      ::Aws.config.update(
        credentials: credentials2.get_credentials,
        region: region || ENV["AWS_DEFAULT_REGION"] || credentials[:region],
        # TODO when we get rid of V1 replace the credentials class with something that knows how
        # to read ~/.aws/config
        :http_proxy => credentials[:proxy_uri] || nil,
        logger: Chef::Log.logger,
        retry_limit: Chef::Config.chef_provisioning[:aws_retry_limit] || 5
      )

      driver = self
      Chef::Resource::Machine.send(:define_method, :aws_object) do
        resource = Chef::Resource::AwsInstance.new(name, nil)
        resource.driver driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        resource.aws_object
      end
      Chef::Resource::MachineImage.send(:define_method, :aws_object) do
        resource = Chef::Resource::AwsImage.new(name, nil)
        resource.driver driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        resource.aws_object
      end
      Chef::Resource::LoadBalancer.send(:define_method, :aws_object) do
        resource = Chef::Resource::AwsLoadBalancer.new(name, nil)
        resource.driver driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        resource.aws_object
      end
    end

    def self.canonicalize_url(driver_url, config)
      [ driver_url, config ]
    end

    # Load balancer methods
    def allocate_load_balancer(action_handler, lb_spec, lb_options, machine_specs)
      lb_options = (lb_options || {}).to_h
      lb_options = AWSResource.lookup_options(lb_options, managed_entry_store: lb_spec.managed_entry_store, driver: self)
      # We delete the attributes and a health check here because they are not valid in the create call
      # and must be applied afterward
      lb_attributes = lb_options.delete(:attributes)
      lb_aws_tags = lb_options.delete(:aws_tags)
      health_check  = lb_options.delete(:health_check)

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
        updates << "  with tags #{lb_options[:aws_tags]}" if lb_options[:aws_tags]

        action_handler.perform_action updates do
          # IAM says the server certificate exists, but ELB throws this error
          Chef::Provisioning::AWSDriver::AWSProvider.retry_with_backoff(AWS::ELB::Errors::CertificateNotFound) do
            actual_elb = elb.load_balancers.create(lb_spec.name, lb_options)
          end

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
        if lb_options[:scheme] && lb_options[:scheme].downcase != actual_elb.scheme
          # TODO CloudFormation automatically recreates the load_balancer, we should too
          raise "Scheme is immutable - you need to :destroy and :create the load_balancer to recreated it with the new scheme"
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
              rescue AWS::ELB::Errors::InvalidConfigurationRequest => e
                Chef::Log.error "You cannot currently move from 1 subnet to another in the same availability zone. " +
                    "Amazon does not have an atomic operation which allows this.  You must create a new " +
                    "ELB with the correct subnets and move instances into it.  Tried to attach subets " +
                    "#{attach_subnets.join(', ')} (availability zones #{enable_zones.join(', ')}) to " +
                    "existing ELB named #{actual_elb.name}"
                raise e
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
              elsif ! server_certificate_eql?(listener.server_certificate,
                                              server_cert_from_spec(desired_listener))
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

      converge_elb_tags(actual_elb, lb_aws_tags, action_handler)

      # Update load balancer attributes
      if lb_attributes
        current = elb.client.describe_load_balancer_attributes(load_balancer_name: actual_elb.name)[:load_balancer_attributes]
        # Need to do a deep copy w/ Marshal load/dump to avoid overwriting current
        desired = deep_merge!(lb_attributes, Marshal.load(Marshal.dump(current)))
        if current != desired
          perform_action.call("  updating attributes to #{desired.inspect}") do
            elb.client.modify_load_balancer_attributes(
              load_balancer_name: actual_elb.name,
              load_balancer_attributes: desired.to_hash
            )
          end
        end
      end

      # Update the load balancer health check, as above
      if health_check
        current = elb.client.describe_load_balancers(load_balancer_names: [actual_elb.name])[:load_balancer_descriptions][0][:health_check]
        desired = deep_merge!(health_check, Marshal.load(Marshal.dump(current)))
        if current != desired
          perform_action.call("  updating health check to #{desired.inspect}") do
            elb.client.configure_health_check(
              load_balancer_name: actual_elb.name,
              health_check: desired.to_hash
            )
          end
        end
      end

      # Update instance list, but only if there are machines specified
      if machine_specs
        assigned_instance_ids = actual_elb.instances.map { |i| i.instance_id }

        instances_to_add = machine_specs.select { |s| !assigned_instance_ids.include?(s.reference['instance_id']) }
        instance_ids_to_remove = assigned_instance_ids - machine_specs.map { |s| s.reference['instance_id'] }

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

    # Compare two server certificates by casting them both to strings.
    #
    # The parameters should either be a String containing the
    # certificate ARN, or a IAM::ServerCertificate object.
    def server_certificate_eql?(cert1, cert2)
      server_cert_to_string(cert1) == server_cert_to_string(cert2)
    end

    def server_cert_to_string(cert)
      if cert.respond_to?(:arn)
        cert.arn
      else
        cert
      end
    end

    # Retreive the server certificate from a listener spec, prefering
    # the server_certificate key.
    def server_cert_from_spec(spec)
      if spec[:server_certificate]
        spec[:server_certificate]
      elsif spec[:ssl_certificate_id]
        spec[:ssl_certificate_id]
      else
        nil
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
      image_options = (image_options || {}).to_h.dup
      machine_options = (machine_options || {}).to_h.dup
      aws_tags = image_options.delete(:aws_tags) || {}
      if actual_image.nil? || !actual_image.exists? || actual_image.state == :failed
        action_handler.perform_action "Create image #{image_spec.name} from machine #{machine_spec.name} with options #{image_options.inspect}" do
          image_options[:name] ||= image_spec.name
          image_options[:instance_id] ||= machine_spec.reference['instance_id']
          image_options[:description] ||= "Image #{image_spec.name} created from machine #{machine_spec.name}"
          Chef::Log.debug "AWS Image options: #{image_options.inspect}"
          actual_image = ec2.images.create(image_options.to_hash)
          image_spec.reference = {
            'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
            'image_id' => actual_image.id,
            'allocated_at' => Time.now.to_i,
            'from-instance' => image_options[:instance_id]
          }
          image_spec.driver_url = driver_url
        end
      end
      aws_tags['from-instance'] = image_options[:instance_id] if image_options[:instance_id]
      converge_ec2_tags(actual_image, aws_tags, action_handler)
    end

    def ready_image(action_handler, image_spec, image_options)
      actual_image = image_for(image_spec)
      if actual_image.nil? || !actual_image.exists?
        raise 'Cannot ready an image that does not exist'
      else
        image_options = (image_options || {}).to_h.dup
        aws_tags = image_options.delete(:aws_tags) || {}
        aws_tags['from-instance'] = image_spec.reference['from-instance'] if image_spec.reference['from-instance']
        converge_ec2_tags(actual_image, aws_tags, action_handler)
        if actual_image.state != :available
          action_handler.report_progress 'Waiting for image to be ready ...'
          wait_until_ready_image(action_handler, image_spec, actual_image)
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
      instance = instance_for(machine_spec)
      bootstrap_options = bootstrap_options_for(action_handler, machine_spec, machine_options)

      if instance == nil || !instance.exists? || instance.state.name == "terminated"
        action_handler.perform_action "Create #{machine_spec.name} with AMI #{bootstrap_options[:image_id]} in #{aws_config.region}" do
          Chef::Log.debug "Creating instance with bootstrap options #{bootstrap_options}"
          instance = create_instance_and_reference(bootstrap_options, action_handler, machine_spec, machine_options)
        end
      end
      converge_ec2_tags(instance, machine_options[:aws_tags], action_handler)
    end

    def allocate_machines(action_handler, specs_and_options, parallelizer)
      create_servers(action_handler, specs_and_options, parallelizer) do |machine_spec, server|
        yield machine_spec
      end
      specs_and_options.keys
    end

    def ready_machine(action_handler, machine_spec, machine_options)
      instance = instance_for(machine_spec)
      converge_ec2_tags(instance, machine_options[:aws_tags], action_handler)

      if instance.nil?
        raise "Machine #{machine_spec.name} does not have an instance associated with it, or instance does not exist."
      end

      if instance.state.name != "running"
        wait_until_machine(action_handler, machine_spec, "finish stopping", instance) { instance.state.name != "stopping" }
        if instance.state.name == "stopped"
          action_handler.perform_action "Start #{machine_spec.name} (#{machine_spec.reference['instance_id']}) in #{aws_config.region} ..." do
            instance.start
          end
        end
        wait_until_ready_machine(action_handler, machine_spec, instance)
      end
1      # byebug
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

    def cloudsearch(api_version="20130101")
      @cloudsearch ||= {}
      @cloudsearch[api_version] ||= AWS::CloudSearch::Client.const_get("V#{api_version}").new
      @cloudsearch[api_version]
    end

    def ec2
      @ec2 ||= AWS::EC2.new(config: aws_config)
    end

    AWS_V2_SERVICES.each do |load_name, short_name|
      class_eval <<-META

      def #{short_name}_client
        @#{short_name}_client ||= ::Aws::#{load_name}::Client.new
      end

      def #{short_name}_resource
        @#{short_name}_resource ||= ::Aws::#{load_name}::Resource.new(#{short_name}_client)
      end

      META
    end

    def elb
      @elb ||= AWS::ELB.new(config: aws_config)
    end

    def elasticache
      @elasticache ||= AWS::ElastiCache::Client.new(config: aws_config)
    end

    def iam
      @iam ||= AWS::IAM.new(config: aws_config)
    end

    def rds
      @rds ||= AWS::RDS.new(config: aws_config)
    end

    def s3
      @s3 ||= AWS::S3.new(config: aws_config)
    end

    def rds
      @rds ||= AWS::RDS.new(config: aws_config)
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

      if machine_spec.reference['is_windows']<
        Chef::Provisioning::Machine::WindowsMachine.new(machine_spec, transport_for(machine_spec, machine_options, instance), convergence_strategy_for(machine_spec, machine_options))
      else
        Chef::Provisioning::Machine::UnixMachine.new(machine_spec, transport_for(machine_spec, machine_options, instance), convergence_strategy_for(machine_spec, machine_options))
      end
    end

    def bootstrap_options_for(action_handler, machine_spec, machine_options)
      bootstrap_options = (machine_options[:bootstrap_options] || {}).to_h.dup
      # These are hardcoded for now - only 1 machine at a time
      bootstrap_options[:min_count] = bootstrap_options[:max_count] = 1
      bootstrap_options[:instance_type] ||= default_instance_type
      image_id = machine_options[:from_image] || bootstrap_options[:image_id] || machine_options[:image_id] || default_ami_for_region(aws_config.region)
      bootstrap_options[:image_id] = image_id
      bootstrap_options.delete(:key_path)
      if !bootstrap_options[:key_name]
        Chef::Log.debug('No key specified, generating a default one...')
        bootstrap_options[:key_name] = default_aws_keypair(action_handler, machine_spec)
      end
      if bootstrap_options[:iam_instance_profile] && bootstrap_options[:iam_instance_profile].is_a?(String)
        bootstrap_options[:iam_instance_profile] = {name: bootstrap_options[:iam_instance_profile]}
      end
      if bootstrap_options[:user_data]
        bootstrap_options[:user_data] = Base64.encode64(bootstrap_options[:user_data])
      end

      # V1 -> V2 backwards compatability support
      unless bootstrap_options.fetch(:monitoring_enabled, nil).nil?
        bootstrap_options[:monitoring] = {enabled: bootstrap_options.delete(:monitoring_enabled)}
      end
      placement = {}
      if bootstrap_options[:availability_zone]
        placement[:availability_zone] = bootstrap_options.delete(:availability_zone)
      end
      if bootstrap_options[:placement_group]
        placement[:group_name] = bootstrap_options.delete(:placement_group)
      end
      unless bootstrap_options.fetch(:dedicated_tenancy, nil).nil?
        placement[:tenancy] = bootstrap_options.delete(:dedicated_tenancy) ? "dedicated" : "default"
      end
      unless placement.empty?
        bootstrap_options[:placement] = placement
      end
      if bootstrap_options[:subnet]
        bootstrap_options[:subnet_id] = bootstrap_options.delete(:subnet)
      end

      bootstrap_options = AWSResource.lookup_options(bootstrap_options, managed_entry_store: machine_spec.managed_entry_store, driver: self)

      # In the migration from V1 to V2 we still support associate_public_ip_address at the top level
      # we do this after the lookup because we have to copy any present subnets, etc. into the
      # network interfaces block
      unless bootstrap_options.fetch(:associate_public_ip_address, nil).nil?
        if bootstrap_options[:network_interfaces]
          raise "If you specify network_interfaces you must specify associate_public_ip_address in that list"
        end
        network_interface = {
          :device_index => 0,
          :associate_public_ip_address => bootstrap_options.delete(:associate_public_ip_address),
          :delete_on_termination => true
        }
        if bootstrap_options[:subnet_id]
          network_interface[:subnet_id] = bootstrap_options.delete(:subnet_id)
        end
        if bootstrap_options[:private_ip_address]
          network_interface[:private_ip_address] = bootstrap_options.delete(:private_ip_address)
        end
        if bootstrap_options[:security_group_ids]
          network_interface[:groups] = bootstrap_options.delete(:security_group_ids)
        end
        bootstrap_options[:network_interfaces] = [network_interface]
      end

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

    def default_ami_arch
      'amd64'
    end

    def default_ami_release
      'vivid'
    end

    def default_ami_root_store
      'ebs'
    end

    def default_ami_virtualization_type
      'hvm'
    end

    def default_ami_for_criteria(region, arch, release, root_store, virtualization_type)
      ami = Ubuntu.release(release).amis.find do |ami|
        ami.arch == arch &&
        ami.root_store == root_store &&
        ami.region == region &&
        ami.virtualization_type == virtualization_type
      end

      ami.name || fail("Default AMI not found")
    end

    def default_ami_for_region(region, criteria = {})
      Chef::Log.debug("Choosing default AMI for region '#{region}'")

      arch = criteria['arch'] || default_ami_arch
      release = criteria['release'] || default_ami_release
      root_store = criteria['root_store'] || default_ami_root_store
      virtualization_type = criteria['virtualization_type'] || default_ami_virtualization_type

      default_ami_for_criteria(region, arch, release, root_store, virtualization_type)
    end

    def create_winrm_transport(machine_spec, machine_options, instance)
      remote_host = determine_remote_host(machine_spec, instance)
      username = machine_spec.reference[:winrm_username] || 'Administrator'
      # default to http for now, should upgrade to https when knife support self-signed
      transport_type = machine_options[:winrm_transport] || 'http'
      type = case transport_type
             when 'http'
               :plaintext
             when 'https'
               :ssl
             end
      if machine_spec.reference[:winrm_port]
        port = machine_spec.reference[:winrm_port]
      else #default port
        port = case transport_type
                 when 'http'
                   '5985'
                 when 'https'
                   '5986'
                 end
      end
      endpoint = "#{transport_type}://#{remote_host}:#{port}/wsman"

      if machine_options[:password]
        password = machine_options[:password]
      else # pull from ec2 and store in reference
        if machine_spec.reference[:winrm_encrypted_password]
          decoded = Base64.decode64(machine_spec.reference[:winrm_encrypted_password])
        else
          encrypted_admin_password = wait_for_admin_password(machine_spec)
          machine_spec.reference[:winrm_encrypted_password]=encrypted_admin_password
          # ^^^ should be saved
          decoded = Base64.decode64(encrypted_admin_password)
        end
        # decrypt so we can utilize
        private_key = OpenSSL::PKey::RSA.new(get_private_key(instance.key_name))
        password = private_key.private_decrypt decoded
      end

      disable_sspi =  machine_options[:winrm_disable_sspi] || false # default to Negotiate
      basic_auth_only = machine_options[:winrm_basic_auth_only] || false # disallow Basic auth by default
      no_ssl_peer_verification = machine_options[:winrm_no_ssl_peer_verification] || false #disallow MITM potential by default

      winrm_options = {
        user: username,
        pass: password,
        disable_sspi: disable_sspi,
        basic_auth_only: basic_auth_only,
        no_ssl_peer_verification: no_ssl_peer_verification,
      }

      if no_ssl_peer_verification or type != :ssl
        # we won't verify certs
      elsif machine_spec.reference[:winrm_ssl_cert]
        # we have stored the cert
      else
        # we need to retrieve the cert and verify it by connecting just to
        # retrieve the ssl certificate and compare it to what we see in the
        # console logs
        console_lines = Base64.decode64(instance.console_output.data.output).lines
        noverify_peer_context = OpenSSL::SSL::SSLContext.new
        noverify_peer_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        tcp_connection = TCPSocket.new(instance.private_ip_address, '5986')
        shady_ssl_connection = OpenSSL::SSL::SSLSocket.new(tcp_connection, noverify_peer_context)
        shady_ssl_connection.connect
        shady_ssl_connection.peer_cert_chain
        winrm_cert = shady_ssl_connection.peer_cert_chain.first

        rdp_thumbprint = console_lines.grep(
          /RDPCERTIFICATE-THUMBPRINT/)[-1].split(': ').last.chomp
        rdp_subject = console_lines.grep(
          /RDPCERTIFICATE-SUBJECTNAME/)[-1].split(': ').last.chomp
        winrm_subject = winrm_cert.subject.to_s.split('=').last.upcase
        winrm_thumbprint=OpenSSL::Digest::SHA1.new(winrm_cert.to_der).to_s.upcase

        if rdp_subject != winrm_subject or rdp_thumbprint != winrm_thumbprint
          Chef::Log.fatal "Winrm ssl port certificate differs from rdp console logs"
        end
        machine_spec.reference[:winrm_ssl_subject]=winrm_subject
        machine_spec.reference[:winrm_ssl_thumbprint]=winrm_thumbprint
        machine_spec.reference[:winrm_ssl_cert]=winrm_cert.to_pem
      end

      # If we have a cert, use it for verification
      if machine_spec.reference[:winrm_ssl_cert]
        FileUtils.mkdir_p(Chef::Config.trusted_certs_dir)
        filename = File.join(Chef::Config.trusted_certs_dir, "#{machine_spec.name}.crt")
        if File.exists?(filename)
          Chef::Log.warn("Existing cert for #{winrm_subject} in #{filename}")
        else
          Chef::Log.warn("Adding certificate for #{winrm_subject} in #{filename}")
          File.open(filename, File::CREAT|File::TRUNC|File::RDWR, 0644) do |f|
            f.print(machine_spec.reference[:winrm_ssl_cert])
          end
        end
        winrm_options[:ca_trust_path] = filename
      end
      Chef::Provisioning::Transport::WinRM.new("#{endpoint}", type, winrm_options, {})
      binding.pry
      # in order for ssl to work, we need to tell ssl that it's ok that ssl_subject doesn't
      # match the ip
      #[19] pry(#<Chef::Provisioning::AWSDriver::Driver>)> endpoint.split('/')[2].split(':').first
      #  => "10.113.70.104"
      #  [20] pry(#<Chef::Provisioning::AWSDriver::Driver>)> machine_spec.reference[:winrm_ssl_subject]
      #    => "IP-0A714668"
      #
      # [1] pry(#<Chef::Provisioning::AWSDriver::Driver>)> Chef::Provisioning::Transport::WinRM.new("#{endpoint}", type, winrm_options, {}).execute('hostname')
      # OpenSSL::SSL::SSLError: SSL_connect returned=1 errno=0 state=error: certificate verify failed
      # from /home/hh/.rvm/gems/ruby-2.2.0/gems/httpclient-2.6.0.1/lib/httpclient/session.rb:307:in `connect'
      # [2] pry(#<Chef::Provisioning::AWSDriver::Driver>)> wtf!
      # Exception: OpenSSL::SSL::SSLError: SSL_connect returned=1 errno=0 state=error: certificate verify failed
      # --
      # 0: /home/hh/.rvm/gems/ruby-2.2.0/gems/httpclient-2.6.0.1/lib/httpclient/session.rb:307:in `connect'
      # 1: /home/hh/.rvm/gems/ruby-2.2.0/gems/httpclient-2.6.0.1/lib/httpclient/session.rb:307:in `ssl_connect'
      # 2: /home/hh/.rvm/gems/ruby-2.2.0/gems/httpclient-2.6.0.1/lib/httpclient/session.rb:755:in `block in connect'
      # 3: /home/hh/.rvm/rubies/ruby-2.2.0/lib/ruby/2.2.0/timeout.rb:89:in `block in timeout'
      # 4: /home/hh/.rvm/rubies/ruby-2.2.0/lib/ruby/2.2.0/timeout.rb:99:in `call'
      # 5: /home/hh/.rvm/rubies/ruby-2.2.0/lib/ruby/2.2.0/timeout.rb:99:in `timeout'
      # 6: /home/hh/.rvm/rubies/ruby-2.2.0/lib/ruby/2.2.0/timeout.rb:125:in `timeout'
      # 7: /home/hh/.rvm/gems/ruby-2.2.0/gems/httpclient-2.6.0.1/lib/httpclient/session.rb:746:in `connect'
      # 8: /home/hh/.rvm/gems/ruby-2.2.0/gems/httpclient-2.6.0.1/lib/httpclient/session.rb:612:in `query'
      # 9: /home/hh/.rvm/gems/ruby-2.2.0/gems/httpclient-2.6.0.1/lib/httpclient/session.rb:164:in `query'
      # [3] pry(#<Chef::Provisioning::AWSDriver::Driver>)> winrm_options
      # => {:user=>"Administrator",
      #  :pass=>"(xntd8f=-HNnuJ3",
      #   :disable_sspi=>false,
      #    :basic_auth_only=>false,
      #     :no_ssl_peer_verification=>false,
      #      :ca_trust_path=>"/home/hh/stratalux/lifelock/misc/provisioning/.chef/trusted_certs/base-2012-hardened-6.crt"}
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
      transport_address_location = (machine_spec.reference['transport_address_location'] || :none).to_sym
      if machine_spec.reference['use_private_ip_for_ssh']
        # The machine_spec has the old config key, lets update it - a successful chef converge will save the machine_spec
        # TODO in 2.0 get rid of this update
        machine_spec.reference.delete('use_private_ip_for_ssh')
        machine_spec.reference['transport_address_location'] = :private_ip
        instance.private_ip_address
      elsif transport_address_location == :private_ip
        instance.private_ip_address
      elsif transport_address_location == :dns
        instance.dns_name
      elsif !instance.public_ip_address && instance.private_ip_address
        Chef::Log.warn("Server #{machine_spec.name} has no public ip address.  Using private ip '#{instance.private_ip_address}'.  Set machine_options ':transport_address_location => :private_ip' if this will always be the case ...")
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
      wait_until_machine(action_handler, machine_spec, "be ready", instance) { |instance|
        instance.state.name == "running"
      }
    end

    def wait_until_machine(action_handler, machine_spec, output_msg, instance=nil, &block)
      instance ||= instance_for(machine_spec)
      # TODO make these configurable from Chef::Config
      max_attempts = 12
      delay = 10
      log_progress = Proc.new do |attempts, response|
        action_handler.report_progress "been waiting #{delay*attempts}/#{delay*max_attempts} -- sleeping #{delay} seconds for #{machine_spec.name} (#{instance.id} on #{driver_url}) to #{output_msg} ..."
      end
      if action_handler.should_perform_actions
        no_wait = yield(instance)
        unless no_wait
          action_handler.report_progress "waiting for #{machine_spec.name} (#{instance.id} on #{driver_url}) to #{output_msg} ..."
          instance.wait_until(:max_attempts => max_attempts, :delay => delay, before_wait: log_progress) do |instance|
            yield(instance)
          end
        end
      end
      # We need an instance.reload here because the `wait_until` does not reload the instance it is called on,
      # only the instance that is passed to the block
      instance.reload
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

    def create_servers(action_handler, specs_and_options, parallelizer)
      specs_and_servers = instances_for(specs_and_options.keys)

      by_bootstrap_options = {}
      specs_and_options.each do |machine_spec, machine_options|
        instance = specs_and_servers[machine_spec]
        if instance
          if instance.state.name == "terminated"
            Chef::Log.warn "Machine #{machine_spec.name} (#{instance.id}) is terminated.  Recreating ..."
          else
            # Even though the instance has been created the tags could be incorrect if it
            # was created before tags were introduced
            converge_ec2_tags(instance, machine_options[:aws_tags], action_handler)
            yield machine_spec, instance if block_given?
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
          parallelizer.parallelize(1.upto(machine_specs.size)) do |i|

            # Assign each one to a machine spec
            machine_spec = machine_specs.pop
            machine_options = specs_and_options[machine_spec]

            clean_bootstrap_options = Marshal.load(Marshal.dump(bootstrap_options))
            instance = create_instance_and_reference(clean_bootstrap_options, action_handler, machine_spec, machine_options)
            converge_ec2_tags(instance, machine_options[:aws_tags], action_handler)

            action_handler.performed_action "machine #{machine_spec.name} created as #{instance.id} on #{driver_url}"

            yield machine_spec, instance if block_given?
          end.to_a

          if machine_specs.size > 0
            raise "Not all machines were created by create_servers"
          end
        end
      end.to_a
    end

    def converge_ec2_tags(aws_object, tags, action_handler)
      ec2_strategy = Chef::Provisioning::AWSDriver::TaggingStrategy::EC2.new(
        ec2_client,
        aws_object.id,
        tags
      )
      aws_tagger = Chef::Provisioning::AWSDriver::AWSTagger.new(ec2_strategy, action_handler)
      aws_tagger.converge_tags
    end

    def converge_elb_tags(aws_object, tags, action_handler)
      elb_strategy = Chef::Provisioning::AWSDriver::TaggingStrategy::ELB.new(
        elb_client,
        aws_object.name,
        tags
      )
      aws_tagger = Chef::Provisioning::AWSDriver::AWSTagger.new(elb_strategy, action_handler)
      aws_tagger.converge_tags
    end

    def create_instance_and_reference(bootstrap_options, action_handler, machine_spec, machine_options)
      instance = ec2_resource.create_instances(bootstrap_options.to_hash)[0]
      # Make sure the instance is ready to be tagged
      instance.wait_until_exists

      # Sometimes tagging fails even though the instance 'exists'
      Retryable.retryable(:tries => 12, :sleep => 5, :on => [::Aws::EC2::Errors::InvalidInstanceIDNotFound]) do
        instance.create_tags({tags: [{key: "Name", value: machine_spec.name}]})
      end
      if machine_options.has_key?(:source_dest_check)
        instance.modify_attribute({
          source_dest_check: {
            value: machine_options[:source_dest_check]
          }
        })
      end
      machine_spec.reference = {
          'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
          'allocated_at' => Time.now.utc.to_s,
          'host_node' => action_handler.host_node,
          'image_id' => bootstrap_options[:image_id],
          'instance_id' => instance.id
      }
      machine_spec.driver_url = driver_url
      machine_spec.reference['key_name'] = bootstrap_options[:key_name] if bootstrap_options[:key_name]
      # TODO 2.0 We no longer support `use_private_ip_for_ssh`, only `transport_address_location`
      if machine_options[:use_private_ip_for_ssh]
        unless @transport_address_location_warned
          Chef::Log.warn("The machine_option ':use_private_ip_for_ssh' has been deprecated, use ':transport_address_location'")
          @transport_address_location_warned = true
        end
        machine_options = Cheffish::MergedConfig.new(machine_options, {:transport_address_location => :private_ip})
      end
      %w(is_windows ssh_username sudo transport_address_location ssh_gateway).each do |key|
        machine_spec.reference[key] = machine_options[key.to_sym] if machine_options[key.to_sym]
      end
      instance
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

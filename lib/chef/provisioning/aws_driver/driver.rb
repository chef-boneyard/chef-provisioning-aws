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

require 'chef/provider/aws_key_pair'
require 'chef/resource/aws_key_pair'
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

    attr_reader :region

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
      @region = region || credentials[:region]
      # TODO: fix credentials here
      AWS.config(:access_key_id => credentials[:aws_access_key_id],
                 :secret_access_key => credentials[:aws_secret_access_key],
                 :region => @region)
    end

    def self.canonicalize_url(driver_url, config)
      [ driver_url, config ]
    end


    # Load balancer methods
    def allocate_load_balancer(action_handler, lb_spec, lb_options, machine_specs)
      if lb_options[:security_group_id]
        security_group = ec2.security_groups[:security_group_id]
      elsif lb_options[:security_group_name]
        security_group = ec2.security_groups.filter('group-name', lb_options[:security_group_name])
      end

      availability_zones = lb_options[:availability_zones]
      listeners = lb_options[:listeners]

      lb_optionals = {}
      lb_optionals[:security_groups] = [security_group] if security_group
      lb_optionals[:availability_zones] = availability_zones if availability_zones
      lb_optionals[:listeners] = listeners if listeners

      actual_elb = load_balancer_for(lb_spec)
      if !actual_elb.exists?
        perform_action = proc { |desc, &block| action_handler.perform_action(desc, &block) }

        updates = [ "Create load balancer #{lb_spec.name} in #{@region}" ]
        updates << "  enable availability zones #{availability_zones.join(', ')}" if availability_zones && availability_zones.size > 0
        updates << "  with listeners #{listeners.join(', ')}" if listeners && listeners.size > 0
        updates << "  with security group #{security_group.name}" if security_group

        action_handler.perform_action updates do
          actual_elb = elb.load_balancers.create(lb_spec.name, lb_optionals)

          lb_spec.location = {
            'driver_url' => driver_url,
            'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
            'allocated_at' => Time.now.utc.to_s,
          }
        end
      else
        # Header gets printed the first time we make an update
        perform_action = proc do |desc, &block|
          perform_action = proc { |desc, &block| action_handler.perform_action(desc, &block) }
          action_handler.perform_action [ "Update load balancer #{lb_spec.name} in #{@region}", desc ].flatten, &block
        end

        # Update availability zones
        enable_zones = (availability_zones || []).dup
        disable_zones = []
        actual_elb.availability_zones.each do |availability_zone|
          if !enable_zones.delete(availability_zone.name)
            disable_zones << availability_zone.name
          end
        end
        if enable_zones.size > 0
          perform_action.call("  enable availability zones #{enable_zones.join(', ')}") do
            actual_elb.availability_zones.enable(*enable_zones)
          end
        end
        if disable_zones.size > 0
          perform_action.call("  disable availability zones #{disable_zones.join(', ')}") do
            actual_elb.availability_zones.disable(*disable_zones)
          end
        end

        # Update listeners
        perform_listener_action = proc do |desc, &block|
          perform_listener_action = proc { |desc, &block| perform_action(desc, &block) }
          perform_action([ "  update listener #{listener.port}", desc ], &block)
        end
        add_listeners = {}
        listeners.each { |l| add_listeners[l[:port]] = l } if listeners
        actual_elb.listeners.each do |listener|
          desired_listener = add_listeners.delete(listener.port)
          if desired_listener
            if listener.protocol != desired_listener[:protocol]
              perform_listener_action.call("    update protocol from #{listener.protocol.inspect} to #{desired_listener[:protocol].inspect}'") do
                listener.protocol = desired_listener[:protocol]
              end
            end
            if listener.instance_port != desired_listener[:instance_port]
              perform_listener_action.call("    update instance port from #{listener.instance_port.inspect} to #{desired_listener[:instance_port].inspect}'") do
                listener.instance_port = desired_listener[:instance_port]
              end
            end
            if listener.instance_protocol != desired_listener[:instance_protocol]
              perform_listener_action.call("    update instance protocol from #{listener.instance_protocol.inspect} to #{desired_listener[:instance_protocol].inspect}'") do
                listener.instance_protocol = desired_listener[:instance_protocol]
              end
            end
            if listener.server_certificate != desired_listener[:server_certificate]
              perform_listener_action.call("    update server certificate from #{listener.server_certificate} to #{desired_listener[:server_certificate]}'") do
                listener.server_certificate = desired_listener[:server_certificate]
              end
            end
          else
            perform_action.call("  remove listener #{listener.port}") do
              listener.delete
            end
          end
        end
        add_listeners.each do |listener|
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

      # Update instance list
      actual_instance_ids = Set.new(actual_elb.instances.map { |i| i.instance_id })

      instances_to_add = machine_specs.select { |s| !actual_instance_ids.include?(s.location['instance_id']) }
      instance_ids_to_remove = actual_instance_ids - machine_specs.map { |s| s.location['instance_id'] }

      if instances_to_add.size > 0
        perform_action.call("  add machines #{instances_to_add.map { |s| s.name }.join(', ')}") do
          instance_ids_to_add = instances_to_add.map { |s| s.location['instance_id'] }
          Chef::Log.debug("Adding instances #{instance_ids_to_add.join(', ')} to load balancer #{actual_elb.name} in region #{@region}")
          actual_elb.instances.add(instance_ids_to_add)
        end
      end

      if instance_ids_to_remove.size > 0
        perform_action.call("  remove instances #{instance_ids_to_remove}") do
          actual_elb.instances.remove(instance_ids_to_remove)
        end
      end
    end

    def ready_load_balancer(action_handler, lb_spec, lb_options, machine_specs)
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
    def allocate_image(action_handler, image_spec, image_options, machine_spec)
      actual_image = image_for(image_spec)
      if actual_image.nil? || !actual_image.exists? || actual_image.state == :failed
        action_handler.perform_action "Create image #{image_spec.name} from machine #{machine_spec.name} with options #{image_options.inspect}" do
          image_options[:name] ||= image_spec.name
          image_options[:instance_id] ||= machine_spec.location['instance_id']
          image_options[:description] ||= "Image #{image_spec.name} created from machine #{machine_spec.name}"
          Chef::Log.debug "AWS Image options: #{image_options.inspect}"
          image = ec2.images.create(image_options.to_hash)
          image_spec.location = {
            'driver_url' => driver_url,
            'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
            'image_id' => image.id,
            'allocated_at' => Time.now.to_i
          }
          image_spec.machine_options ||= {}
          image_spec.machine_options.merge!({
            :bootstrap_options => {
                :image_id => image.id
            }
          })
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
      actual_image = image_for(image_spec)
      snapshots = snapshots_for(image_spec)
      if actual_image.nil? || !actual_image.exists?
        Chef::Log.warn "Image #{image_spec.name} doesn't exist"
      else
        action_handler.perform_action "De-registering image #{image_spec.name}" do
          actual_image.deregister
        end
        unless snapshots.any?
          action_handler.perform_action "Deleting image #{image_spec.name} snapshots" do
            snapshots.each do |snap|
              snap.delete
            end
          end
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
        image_id = machine_options[:image_id] || default_ami_for_region(@region)
        bootstrap_options = (machine_options[:bootstrap_options] || {}).to_h.dup
        bootstrap_options[:image_id] = image_id
        if !bootstrap_options[:key_name]
          Chef::Log.debug('No key specified, generating a default one...')
          bootstrap_options[:key_name] = default_aws_keypair(action_handler, machine_spec)
        end

        puts "#{machine_options.inspect}"

        if machine_options[:is_windows]
          Chef::Log.info "Setting winRM userdata..."
          bootstrap_options[:user_data] = user_data
        else
          Chef::Log.info "Non-windows, not setting userdata"
        end

        Chef::Log.debug "AWS Bootstrap options: #{bootstrap_options.inspect}"

        action_handler.perform_action "Create #{machine_spec.name} with AMI #{image_id} in #{@region}" do
          Chef::Log.debug "Creating instance with bootstrap options #{bootstrap_options}"

          instance = ec2.instances.create(bootstrap_options.to_hash)

          # Make sure the instance is ready to be tagged
          sleep 5 while instance.status == :pending
          # TODO add other tags identifying user / node url (same as fog)
          instance.tags['Name'] = machine_spec.name
          machine_spec.location = {
              'driver_url' => driver_url,
              'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
              'allocated_at' => Time.now.utc.to_s,
              'host_node' => action_handler.host_node,
              'image_id' => machine_options[:image_id],
              'instance_id' => instance.id
          }
          machine_spec.location['key_name'] = bootstrap_options[:key_name] if bootstrap_options[:key_name]
          %w(is_windows ssh_username sudo use_private_ip_for_ssh ssh_gateway).each do |key|
            machine_spec.location[key] = machine_options[key.to_sym] if machine_options[key.to_sym]
          end
        end
      end
    end

    def allocate_machines(action_handler, specs_and_options, parallelizer)
      #Chef::Log.warn("#{specs_and_options}")
      create_servers(action_handler, specs_and_options, parallelizer) do |machine_spec, server|
    #Chef::Log.warn("#{machine_spec}")
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
          action_handler.perform_action "Start #{machine_spec.name} (#{machine_spec.location['instance_id']}) in #{@region} ..." do
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

      machine_for(machine_spec, machine_spec.location)
    end

    def destroy_machine(action_handler, machine_spec, machine_options)
      instance = instance_for(machine_spec)
      if instance && instance.exists?
        # TODO do we need to wait_until(action_handler, machine_spec, instance) { instance.status != :shutting_down } ?
        action_handler.perform_action "Terminate #{machine_spec.name} (#{machine_spec.location['instance_id']}) in #{@region} ..." do
          instance.terminate
          machine_spec.location = nil
        end
      else
        Chef::Log.warn "Instance #{machine_spec.location['instance_id']} doesn't exist for #{machine_spec.name}"
      end

      strategy = convergence_strategy_for(machine_spec, machine_options)
      strategy.cleanup_convergence(action_handler, machine_spec)
    end

    private

    # For creating things like AWS keypairs exclusively
    @@chef_default_lock = Mutex.new

    def machine_for(machine_spec, machine_options, instance = nil)
      instance ||= instance_for(machine_spec)

      if !instance
        raise "Instance for node #{machine_spec.name} has not been created!"
      end

      if machine_spec.location['is_windows']
        Chef::Provisioning::Machine::WindowsMachine.new(machine_spec, transport_for(machine_spec, machine_options, instance), convergence_strategy_for(machine_spec, machine_options))
      else
        Chef::Provisioning::Machine::UnixMachine.new(machine_spec, transport_for(machine_spec, machine_options, instance), convergence_strategy_for(machine_spec, machine_options))
      end
    end

    def start_machine(action_handler, machine_spec, machine_options, base_image_name)
    end

    def ec2
      @ec2 ||= AWS.ec2
    end

    def elb
      @elb ||= AWS::ELB.new
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
      if lb_spec.name
        elb.load_balancers[lb_spec.name]
      else
        nil
      end
    end

    def instance_for(machine_spec)
      if machine_spec.location && machine_spec.location['instance_id']
        ec2.instances[machine_spec.location['instance_id']]
      end
    end

    def instances_for(machine_specs)
      result = {}
      machine_specs.each do |machine_spec|
        if machine_spec.location && machine_spec.location['instance_id']
          if machine_spec.location['driver_url'] != driver_url
            raise "Switching a machine's driver from #{machine_spec.location['driver_url']} to #{driver_url} is not currently supported!  Use machine :destroy and then re-create the machine on the new driver."
          end
          #returns nil if not found
          result[machine_spec] = ec2.instances[machine_spec.location['instance_id']]
        end
      end
      result
    end

    def image_for(image_spec)
      if image_spec.location && image_spec.location['image_id']
        ec2.images[image_spec.location['image_id']]
      end
    end

    def snapshots_for(image_spec)
      if image_spec.location && image_spec.location['image_id']
        actual_image = image_for(image_spec)
        snapshots = []
        actual_image.block_device_mappings.each do |dev, opts|
            snapshots << ec2.snapshots[opts[:snapshot_id]]
        end
        snapshots
      end
    end

    def transport_for(machine_spec, machine_options, instance)
      if machine_spec.location['is_windows']
        create_winrm_transport(machine_spec, machine_options, instance)
      else
        create_ssh_transport(machine_spec, machine_options, instance)
      end
    end

    def compute_options

    end

    def aws_credentials
      # Grab the list of possible credentials
      @aws_credentials ||= if driver_options[:aws_credentials]
                             driver_options[:aws_credentials]
                           else
                             credentials = Credentials.new
                             if driver_options[:aws_config_file]
                               credentials.load_ini(driver_options.delete(:aws_config_file))
                             elsif driver_options[:aws_csv_file]
                               credentials.load_csv(driver_options.delete(:aws_csv_file))
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
          'ami-c786dcc6'
        when 'ap-southeast-1'
          'ami-eefca7bc'
        when 'ap-southeast-2'
          'ami-996706a3'
        when 'eu-west-1'
          'ami-4ab46b3d'
        when 'eu-central-1'
          'ami-7c3c0a61'
        when 'sa-east-1'
          'ami-6770d87a'
        when 'us-east-1'
          'ami-d2ff23ba'
        when 'us-west-1'
          'ami-73717d36'
        when 'us-west-2'
          'ami-f1ce8bc1'
        else
          raise 'Unsupported region!'
      end
    end

    def create_winrm_transport(machine_spec, machine_options, instance)
      remote_host = determine_remote_host(machine_spec, instance)
      puts "remote host: #{remote_host}"
      port = machine_spec.location['winrm_port'] || 5985
      endpoint = "http://#{remote_host}:#{port}/wsman"
      type = :plaintext
      pem_bytes = get_private_key(instance.key_name)
      encrypted_admin_password = wait_for_admin_password(machine_spec)

      decoded = Base64.decode64(encrypted_admin_password)
      private_key = OpenSSL::PKey::RSA.new(pem_bytes)
      decrypted_password = private_key.private_decrypt decoded

      winrm_options = {
        :user => machine_spec.location['winrm_username'] || 'Administrator',
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
      instance_id = machine_spec.location['instance_id']

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
      username = machine_spec.location['ssh_username'] || machine_options[:ssh_username] || default_ssh_username
      if machine_options.has_key?(:ssh_username) && machine_options[:ssh_username] != machine_spec.location['ssh_username']
        Chef::Log.warn("Server #{machine_spec.name} was created with SSH username #{machine_spec.location['ssh_username']} and machine_options specifies username #{machine_options[:ssh_username]}.  Using #{machine_spec.location['ssh_username']}.  Please edit the node and change the chef_provisioning.location.ssh_username attribute if you want to change it.")
      end
      options = {}
      if machine_spec.location[:sudo] || (!machine_spec.location.has_key?(:sudo) && username != 'root')
        options[:prefix] = 'sudo '
      end

      remote_host = determine_remote_host(machine_spec, instance)

      #Enable pty by default
      options[:ssh_pty_enable] = true
      options[:ssh_gateway] = machine_spec.location['ssh_gateway'] if machine_spec.location.has_key?('ssh_gateway')

      Chef::Provisioning::Transport::SSH.new(remote_host, username, ssh_options, options, config)
    end

    def determine_remote_host(machine_spec, instance)
      if machine_spec.location['use_private_ip_for_ssh']
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
      elsif machine_spec.location['key_name']
        key = get_private_key(machine_spec.location['key_name'])
        unless key
          raise "Server was created with key name '#{machine_spec.location['key_name']}', but the corresponding private key was not found locally.  Check if the key is in Chef::Config.private_key_paths: #{Chef::Config.private_key_paths.join(', ')}"
        end
        result[:key_data] = [ key ]
      elsif machine_options[:bootstrap_options] && machine_options[:bootstrap_options][:key_path]
        result[:key_data] = [ IO.read(machine_options[:bootstrap_options][:key_path]) ]
      elsif machine_options[:bootstrap_options] && machine_options[:bootstrap_options][:key_name]
        result[:key_data] = [ get_private_key(machine_options[:bootstrap_options][:key_name]) ]
      else
        # TODO make a way to suggest other keys to try ...
        raise "No key found to connect to #{machine_spec.name} (#{machine_spec.location.inspect})!"
      end
      result
    end

    def convergence_strategy_for(machine_spec, machine_options)
      # Tell Ohai that this is an EC2 instance so that it runs the EC2 plugin
      convergence_options = Cheffish::MergedConfig.new(
        machine_options[:convergence_options] || {},
        ohai_hints: { 'ec2' => '' })

      # Defaults
      if !machine_spec.location
        return Chef::Provisioning::ConvergenceStrategy::NoConverge.new(convergence_options, config)
      end

      if machine_spec.location['is_windows']
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
      max_wait_time = 120
      if !yield(image)
        action_handler.report_progress "waiting for #{image_spec.name} (#{image.id} on #{driver_url}) to be ready ..."
        while time_elapsed < 120 && !yield(image)
          action_handler.report_progress "been waiting #{time_elapsed}/#{max_wait_time} -- sleeping #{sleep_time} seconds for #{image_spec.name} (#{image.id} on #{driver_url}) to be ready ..."
          sleep(sleep_time)
          time_elapsed += sleep_time
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
          while time_elapsed < 120 && !yield(instance)
            action_handler.report_progress "been waiting #{time_elapsed}/#{max_wait_time} -- sleeping #{sleep_time} seconds for #{machine_spec.name} (#{instance.id} on #{driver_url}) to be ready ..."
            sleep(sleep_time)
            time_elapsed += sleep_time
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
          while time_elapsed < 120 && !transport.available?
            action_handler.report_progress "been waiting #{time_elapsed}/#{max_wait_time} -- sleeping #{sleep_time} seconds for #{machine_spec.name} (#{instance.id} on #{driver_url}) to be connectable ..."
            sleep(sleep_time)
            time_elapsed += sleep_time
          end

          action_handler.report_progress "#{machine_spec.name} is now connectable"
        end
      end
    end

    def default_aws_keypair_name(machine_spec)
      if machine_spec.location &&
          Gem::Version.new(machine_spec.location['driver_version']) < Gem::Version.new('0.10')
        'metal_default'
      else
        'chef_default'
      end
    end

    def default_aws_keypair(action_handler, machine_spec)
      driver = self
      default_key_name = default_aws_keypair_name(machine_spec)
      _region = region
      updated = @@chef_default_lock.synchronize do
        Provisioning.inline_resource(action_handler) do
          aws_key_pair default_key_name do
            driver driver
            allow_overwrite true
            region_name _region
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
        elsif machine_spec.location
          Chef::Log.warn "Machine #{machine_spec.name} (#{machine_spec.location['instance_id']} on #{driver_url}) no longer exists.  Recreating ..."
        end

        bootstrap_options = machine_options[:bootstrap_options] || {}
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
            machine_spec.location = {
              'driver_url' => driver_url,
              'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
              'allocated_at' => Time.now.utc.to_s,
              'host_node' => action_handler.host_node,
              'image_id' => bootstrap_options[:image_id],
              'instance_id' => instance.id
            }
            instance.tags['Name'] = machine_spec.name
            machine_spec.location['key_name'] = bootstrap_options[:key_name] if bootstrap_options[:key_name]
            %w(is_windows ssh_username sudo use_private_ip_for_ssh ssh_gateway).each do |key|
              machine_spec.location[key] = machine_options[key.to_sym] if machine_options[key.to_sym]
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

  end
end
end
end
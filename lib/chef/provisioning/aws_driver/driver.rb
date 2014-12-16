require 'chef/mixin/shell_out'
require 'chef/provisioning/driver'
require 'chef/provisioning/convergence_strategy/install_cached'
require 'chef/provisioning/convergence_strategy/install_sh'
require 'chef/provisioning/convergence_strategy/no_converge'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/machine/windows_machine'
require 'chef/provisioning/machine/unix_machine'
require 'chef/provisioning/machine_spec'

require 'chef/provider/aws_key_pair'
require 'chef/resource/aws_key_pair'
require 'chef/provisioning/aws_driver/version'
require 'chef/provisioning/aws_driver/credentials'

require 'yaml'
require 'aws-sdk-v1'


class Chef
module Provisioning
module AWSDriver
  # Provisions machines using the AWS SDK
  class Driver < Chef::Provisioning::Driver

    include Chef::Mixin::ShellOut

    attr_reader :region

    # URL scheme:
    # aws:account_id:region
    # TODO: migration path from fog:AWS - parse that URL
    # canonical URL calls realpath on <path>
    def self.from_url(driver_url, config)
      Driver.new(driver_url, config)
    end

    def initialize(driver_url, config)
      super
      credentials = aws_credentials.default
      @region = credentials[:region]
      # TODO: fix credentials here
      AWS.config(:access_key_id => credentials[:aws_access_key_id],
                 :secret_access_key => credentials[:aws_secret_access_key],
                 :region => credentials[:region])
    end

    def self.canonicalize_url(driver_url, config)
      url = driver_url.split(":")[0]
      [ "aws:#{url}", config ]
    end


    # Load balancer methods
    def allocate_load_balancer(action_handler, lb_spec, lb_options, machine_specs)
      security_group_name = lb_options[:security_group_name] || 'default'
      security_group_id = lb_options[:security_group_id]

      security_group = if security_group_id.nil?
                         ec2.security_groups.filter('group-name', security_group_name).first
                       else
                         ec2.security_groups[security_group_id]
                       end
      availability_zones = lb_options[:availability_zones]
      listeners = lb_options[:listeners]

      actual_elb = load_balancer_for(lb_spec)
      if !actual_elb.exists?
        perform_action = proc { |desc, &block| action_handler.perform_action(desc, &block) }

        updates = [ "Create load balancer #{lb_spec.name} in #{@region}" ]
        updates << "  enable availability zones #{availability_zones.join(', ')}" if availability_zones && availability_zones.size > 0
        updates << "  with listeners #{listeners.join(', ')}" if listeners && listeners.size > 0
        updates << "  with security group #{security_group.name}" if security_group

        action_handler.perform_action updates do
          actual_elb = elb.load_balancers.create(lb_spec.name,
            availability_zones: availability_zones,
            listeners:          listeners,
            security_groups:    [security_group])

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
    end

    def ready_image(action_handler, image_spec, image_options)
    end

    def destroy_image(action_handler, image_spec, image_options)
    end

    # Machine methods
    def allocate_machine(action_handler, machine_spec, machine_options)
      actual_instance = instance_for(machine_spec)
      if actual_instance == nil || !actual_instance.exists? || actual_instance.status == :terminated
        image_id = machine_options[:image_id] || default_ami_for_region(@region)
        bootstrap_options = machine_options[:bootstrap_options] || {}
        bootstrap_options[:image_id] = image_id
        if !bootstrap_options[:key_name]
          Chef::Log.debug('No key specified, generating a default one...')
          bootstrap_options[:key_name] = default_aws_keypair(action_handler, machine_spec)
        end
        Chef::Log.debug "AWS Bootstrap options: #{bootstrap_options.inspect}"

        action_handler.perform_action "Create #{machine_spec.name} with AMI #{image_id} in #{@region}" do
          Chef::Log.debug "Creating instance with bootstrap options #{bootstrap_options}"
          instance = ec2.instances.create(bootstrap_options)
          # TODO add other tags identifying user / node url (same as fog)
          instance.tags['Name'] = machine_spec.name
          machine_spec.location = {
              'driver_url' => driver_url,
              'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
              'allocated_at' => Time.now.utc.to_s,
              'host_node' => action_handler.host_node,
              'image_id' => machine_options[:image_id],
              'ssh_username' => machine_options[:ssh_username],
              'instance_id' => instance.id
          }
        end
      end
    end

    def ready_machine(action_handler, machine_spec, machine_options)
      instance = instance_for(machine_spec)

      if instance.nil?
        raise "Machine #{machine_spec.name} does not have an instance associated with it, or instance does not exist."
      end

      if instance.status != :running
        wait_until(action_handler, machine_spec, instance) { instance.status != :stopping }
        if instance.status == :stopped
          action_handler.perform_action "Start #{machine_spec.name} (#{machine_spec.location['instance_id']}) in #{@region} ..." do
            instance.start
          end
        end
        wait_until_ready(action_handler, machine_spec, instance)
        wait_for_transport(action_handler, machine_spec, machine_options)
      end

      machine_for(machine_spec, machine_options, instance)

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
      else
        nil
      end
    end

    def transport_for(machine_spec, machine_options, instance)
      # TODO winrm
      create_ssh_transport(machine_spec, machine_options, instance)
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

    def create_ssh_transport(machine_spec, machine_options, instance)
      ssh_options = ssh_options_for(machine_spec, machine_options, instance)
      username = machine_spec.location['ssh_username'] || default_ssh_username
      if machine_options.has_key?(:ssh_username) && machine_options[:ssh_username] != machine_spec.location['ssh_username']
        Chef::Log.warn("Server #{machine_spec.name} was created with SSH username #{machine_spec.location['ssh_username']} and machine_options specifies username #{machine_options[:ssh_username]}.  Using #{machine_spec.location['ssh_username']}.  Please edit the node and change the chef_provisioning.location.ssh_username attribute if you want to change it.")
      end
      options = {}
      if machine_spec.location[:sudo] || (!machine_spec.location.has_key?(:sudo) && username != 'root')
        options[:prefix] = 'sudo '
      end

      remote_host = nil

      if machine_spec.location['use_private_ip_for_ssh']
        remote_host = instance.private_ip_address
      elsif !instance.public_ip_address
        Chef::Log.warn("Server #{machine_spec.name} has no public ip address.  Using private ip '#{instance.private_ip_address}'.  Set driver option 'use_private_ip_for_ssh' => true if this will always be the case ...")
        remote_host = instance.private_ip_address
      elsif instance.public_ip_address
        remote_host = instance.public_ip_address
      else
        raise "Server #{instance.id} has no private or public IP address!"
      end

      #Enable pty by default
      options[:ssh_pty_enable] = true
      options[:ssh_gateway] = machine_spec.location['ssh_gateway'] if machine_spec.location.has_key?('ssh_gateway')

      Chef::Provisioning::Transport::SSH.new(remote_host, username, ssh_options, options, config)
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
      machine_options[:convergence_options] ||= {}
      machine_options[:convergence_options][:ohai_hints] = { 'ec2' => ''}

      # Defaults
      if !machine_spec.location
        return Chef::Provisioning::ConvergenceStrategy::NoConverge.new(machine_options[:convergence_options], config)
      end

      if machine_spec.location['is_windows']
        Chef::Provisioning::ConvergenceStrategy::InstallMsi.new(machine_options[:convergence_options], config)
      elsif machine_options[:cached_installer] == true
        Chef::Provisioning::ConvergenceStrategy::InstallCached.new(machine_options[:convergence_options], config)
      else
        Chef::Provisioning::ConvergenceStrategy::InstallSh.new(machine_options[:convergence_options], config)
      end
    end

    def wait_until_ready(action_handler, machine_spec, instance=nil)
      wait_until(action_handler, machine_spec, instance) { instance.status == :running }
    end

    def wait_until(action_handler, machine_spec, instance=nil, &block)
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
      default_warning = 'Using default key, which is not shared between machines!  It is recommended to create an AWS key pair with the fog_key_pair resource, and set :bootstrap_options => { :key_name => <key name> }'
      Chef::Log.warn(default_warning) if updated

      default_key_name
    end

  end
end
end
end

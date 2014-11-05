require 'chef/mixin/shell_out'
require 'chef/provisioning/driver'
require 'chef/provisioning/convergence_strategy/install_cached'
require 'chef/provisioning/convergence_strategy/install_sh'
require 'chef/provisioning/convergence_strategy/no_converge'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/machine/windows_machine'
require 'chef/provisioning/machine/unix_machine'
require 'chef/provisioning/machine_spec'

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
    def allocate_load_balancer(action_handler, lb_spec, lb_options)
      existing_elb = load_balancer_for(lb_spec)
      if !existing_elb.exists?
        lb_spec.location = {
            'driver_url' => driver_url,
            'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
            'allocated_at' => Time.now.utc.to_s,
            'host_node' => action_handler.host_node,
        }

        security_group_name = lb_options[:security_group_name] || 'default'
        security_group_id = lb_options[:security_group_id]

        default_sg = ec2.security_groups.filter('group-name', 'default')
        security_group = if security_group_id.nil?
                           ec2.security_groups.filter('group-name', security_group_name).first
                         else
                           ec2.security_groups[security_group_id]
                         end

        availability_zones = lb_options[:availability_zones]
        listeners = lb_options[:listeners]
        elb.load_balancers.create(lb_spec.name,
                :availability_zones => availability_zones,
                :listeners => listeners,
                :security_groups => [security_group])
      end
    end

    def ready_load_balancer(action_handler, lb_spec, lb_options)
    end

    def destroy_load_balancer(action_handler, lb_spec, lb_options)
    end

    # TODO update listeners and zones, and other bits
    def update_load_balancer(action_handler, lb_spec, lb_options, opts = {})
      existing_elb = load_balancer_for(lb_spec)

      # Try to recreate it if it doesn't exist in AWS
      action_handler.report_progress "Checking for ELB named #{lb_spec.name}..."
      allocate_load_balancer(action_handler, lb_spec, lb_options) unless existing_elb.exists?

      # Try to find it again -- if we can't, consider it fatal
      existing_elb = load_balancer_for(lb_spec)
      fail "Unable to find specified ELB instance. Already tried to recreate it!" if !existing_elb.exists?

      action_handler.report_progress "Updating ELB named #{lb_spec.name}..."

      machines = opts[:machines]
      existing_instance_ids = existing_elb.instances.collect { |i| i.instance_id }

      new_instance_ids = machines.keys.collect do |machine_name|
        machine_spec = machines[machine_name]
        machine_spec.location['instance_id']
      end

      instance_ids_to_add = new_instance_ids - existing_instance_ids
      instance_ids_to_remove = existing_instance_ids - new_instance_ids

      if instance_ids_to_add && instance_ids_to_add.size > 0
        action_handler.perform_action "Adding instances: #{instance_ids_to_add}" do
          existing_elb.instances.add(instance_ids_to_add)
        end
      end

      if instance_ids_to_remove && instance_ids_to_remove.size > 0
        action_handler.perform_action "Removing instances: #{instance_ids_to_remove}" do
          existing_elb.instances.remove(instance_ids_to_remove)
        end
      end
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
      existing_instance = instance_for(machine_spec)
      if existing_instance == nil || !existing_instance.exists?

        machine_spec.location = {
            'driver_url' => driver_url,
            'driver_version' => Chef::Provisioning::AWSDriver::VERSION,
            'allocated_at' => Time.now.utc.to_s,
            'host_node' => action_handler.host_node,
            'image_id' => machine_options[:image_id]
        }

        image_id = machine_options[:image_id] || default_ami_for_region(@region)
        action_handler.report_progress "Creating #{machine_spec.name} with AMI #{image_id} in #{@region}..."
        bootstrap_options = machine_options[:bootstrap_options] || {}
        bootstrap_options[:image_id] = image_id
        Chef::Log.debug "AWS Bootstrap options: #{bootstrap_options.inspect}"
        instance = ec2.instances.create(bootstrap_options)
        instance.tags['Name'] = machine_spec.name
        machine_spec.location['instance_id'] = instance.id
        action_handler.report_progress "Created #{instance.id} in #{@region}..."
      end
    end

    def ready_machine(action_handler, machine_spec, machine_options)
      instance = instance_for(machine_spec)

      if instance.nil?
        raise "Machine #{machine_spec.name} does not have an instance associated with it, or instance does not exist."
      end

      if instance.status != :running
        action_handler.report_progress "Starting #{machine_spec.name} (#{machine_spec.location['instance_id']}) in #{@region}..."
        wait_until_ready(action_handler, machine_spec)
        wait_for_transport(action_handler, machine_spec, machine_options)
      else
        action_handler.report_progress "#{machine_spec.name} (#{machine_spec.location['instance_id']}) already running in #{@region}..."
      end

      machine_for(machine_spec, machine_options, instance)

    end

    def destroy_machine(action_handler, machine_spec, machine_options)
      instance = instance_for(machine_spec)
      if instance
        instance.terminate
      end
    end




    private
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
        existing_key_pair = ec2.key_pairs[keypair_name]
        if !existing_key_pair.exists?
          ec2.key_pairs.create(keypair_name)
        end
        existing_key_pair
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

    def wait_until_ready(action_handler, machine_spec)
      instance = instance_for(machine_spec)
      time_elapsed = 0
      sleep_time = 10
      max_wait_time = 120
      unless instance.status == :running
        if action_handler.should_perform_actions
          action_handler.report_progress "waiting for #{machine_spec.name} (#{instance.id} on #{driver_url}) to be ready ..."
          while time_elapsed < 120 && instance.status != :running
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

  end
end
end
end

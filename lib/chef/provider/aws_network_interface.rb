require 'chef/provisioning/aws_driver/aws_provider'
require 'cheffish'
require 'date'
require 'retryable'

class Chef::Provider::AwsNetworkInterface < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::EC2ConvergeTags

  provides :aws_network_interface

  class NetworkInterfaceStatusTimeoutError < ::Timeout::Error
    def initialize(new_resource, initial_status, expected_status)
      super("timed out waiting for #{new_resource} status to change from #{initial_status} to #{expected_status}!")
    end
  end

  class NetworkInterfaceInvalidStatusError < RuntimeError
    def initialize(new_resource, status)
      super("#{new_resource} is in #{status} state!")
    end
  end

  def action_create
    eni = super

    if !new_resource.machine.nil?
      update_eni(eni)
    end
  end

  protected

  def create_aws_object
    eni = nil
    converge_by "create new #{new_resource} in #{region}" do
      eni = new_resource.driver.ec2.network_interfaces.create(options)
      retry_with_backoff(AWS::EC2::Errors::InvalidNetworkInterfaceID::NotFound) do
        eni.tags['Name'] = new_resource.name
      end
      eni
    end

    converge_by "wait for new #{new_resource} in #{region} to become available" do
      wait_for_status(eni, :available)
      eni
    end
  end

  def update_aws_object(eni)
    if options.has_key?(:subnet)
      if Chef::Resource::AwsSubnet.get_aws_object(options[:subnet], resource: new_resource) != eni.subnet
        raise "#{new_resource} subnet is #{new_resource.subnet}, but actual network interface has subnet set to #{eni.subnet_id}.  Cannot be modified!"
      end
    end

    # TODO implement private ip reassignment
    if options.has_key?(:private_ip_address)
      if options[:private_ip_address] != eni.private_ip_address
        raise "#{new_resource} private IP is #{new_resource.private_ip_address}, but actual network interface has private IP set to #{eni.private_ip_address}.  Private IP reassignment not implemented. Cannot be modified!"
      end
    end

    if options.has_key?(:description)
      if options[:description] != eni.description
        converge_by "set #{new_resource} description to #{new_resource.description}" do
          eni.client.modify_network_interface_attribute(:network_interface_id => eni.network_interface_id,
                                                        :description => {
                                                            :value => new_resource.description
                                                        })
        end
      end
    end

    if options.has_key?(:security_groups)
      groups = new_resource.security_groups.map { |sg|
        Chef::Resource::AwsSecurityGroup.get_aws_object(sg, resource: new_resource)
      }
      if groups.sort != eni.security_groups.sort
        converge_by "set #{new_resource} security groups to #{groups}" do
          eni.set_security_groups(groups)
          eni
        end
      end
    end

    eni
  end

  def destroy_aws_object(eni)
    detach(eni) if eni.status == :in_use
    delete(eni)
  end

  private

  def expected_instance
    # use instance if already set
    @expected_instance ||= new_resource.machine ?
      # if not, and machine is set, find and return the instance
        Chef::Resource::AwsInstance.get_aws_object(new_resource.machine, resource: new_resource) :
      # otherwise return nil
        nil
  end

  def options
    @options ||= begin
      options = {}
      options[:subnet] = new_resource.subnet if !new_resource.subnet.nil?
      options[:private_ip_address] = new_resource.private_ip_address if !new_resource.private_ip_address.nil?
      options[:description] = new_resource.description if !new_resource.description.nil?
      options[:security_groups] = new_resource.security_groups if !new_resource.security_groups.nil?
      options[:device_index] = new_resource.device_index if !new_resource.device_index.nil?

      AWSResource.lookup_options(options, resource: new_resource)
    end
  end

  def update_eni(eni)
    status = eni.status
    #
    # If we were told to attach the network interface to a machine, do so
    #
    if expected_instance.is_a?(AWS::EC2::Instance) || expected_instance.is_a?(::Aws::EC2::Instance)
      case status
      when :available
        attach(eni)
      when :in_use
        # We don't want to attempt to reattach to the same instance or device index
        attachment = current_attachment(eni)
        if attachment.instance.id != expected_instance.id || (options[:device_index] && attachment.device_index != new_resource.device_index)
          detach(eni)
          attach(eni)
        end
      when nil
        raise NetworkInterfaceNotFoundError.new(new_resource)
      else
        raise NetworkInterfaceInvalidStatusError.new(new_resource, status)
      end

    #
    # If we were told to set the machine to false, detach it.
    #
    else
      case status
      when nil
        Chef::Log.warn NetworkInterfaceNotFoundError.new(new_resource)
      when :in_use
        detach(eni)
      end
    end
    eni
  end

  def detach(eni)
    attachment   = current_attachment(eni)
    instance     = attachment.instance

    converge_by "detach #{new_resource} from #{instance.id}" do
      eni.detach
    end

    converge_by "wait for #{new_resource} to detach" do
      wait_for_status(eni, :available)
      eni
    end
  end

  def attach(eni)
    converge_by "attach #{new_resource} to #{new_resource.machine} (#{expected_instance.id})" do
      eni.attach(expected_instance.id, options)
    end

    converge_by "wait for #{new_resource} to attach" do
      wait_for_status(eni, :in_use)
      eni
    end
  end

  def current_attachment(eni)
    eni.attachment
  end

  def delete(eni)
    converge_by "delete #{new_resource} in #{region}" do
      eni.delete
    end

    converge_by "wait for #{new_resource} in #{region} to delete" do
      log_callback = proc {
        Chef::Log.info('waiting for network interface to delete...')
      }

      Retryable.retryable(:tries => 30, :sleep => 2, :on => NetworkInterfaceStatusTimeoutError, :ensure => log_callback) do
        raise NetworkInterfaceStatusTimeoutError.new(new_resource, 'exists', 'deleted') if eni.exists?
      end
      eni
    end
  end
end

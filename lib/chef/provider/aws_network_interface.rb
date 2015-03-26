require 'chef/provisioning/aws_driver/aws_provider'
require 'cheffish'
require 'date'
require 'retryable'

class Chef::Provider::AwsNetworkInterface < Chef::Provisioning::AWSDriver::AWSProvider
  class NetworkInterfaceStatusTimeoutError < TimeoutError
    def initialize(new_resource, initial_status, expected_status)
      super("timed out waiting for #{new_resource} status to change from #{initial_status} to #{expected_status}!")
    end
  end

  class NetworkInterfaceStatusTimeoutError < TimeoutError
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
      eni = new_resource.driver.ec2.network_interfaces.create(initial_options)
      eni.tags['Name'] = new_resource.name
    end

    converge_by "wait for new #{new_resource} in #{region} to become available" do
      wait_for_eni_status(eni, :available)
      eni
    end
  end

  def update_aws_object(eni)
    # if initial_options.has_key?(:subnet)
    #   if initial_options[:subnet] != eni.subnet
    #     raise "#{new_resource} is #{new_resource.subnet}, but actual network interface has subnet set to #{eni.subnet_id}.  Cannot be modified!"
    #   end
    # end
  end

  def destroy_aws_object(eni)
    # detach(volume) if volume.status == :in_use
    delete(eni)
  end

  private

  def expected_instance
    if !defined?(@expected_instance)
      if new_resource.machine == false
        @expected_instance = nil
      else
        @expected_instance = Chef::Resource::AwsInstance.get_aws_object(new_resource.machine, resource: new_resource)
      end
    end
    @expected_instance
  end

  def initial_options
    @initial_options ||= begin
      options = {}
      options[:subnet] = new_resource.subnet if !new_resource.subnet.nil?

      AWSResource.lookup_options(options, resource: new_resource)
    end
  end

  def update_eni(eni)
    status = eni.status
    #
    # If we were told to attach the volume to a machine, do so
    #
    if expected_instance.is_a?(AWS::EC2::Instance)
      case status
      when :available
        attach(eni)
      when :in_use
        # We don't want to attempt to reattach to the same instance or device index
        attachment = current_attachment(eni)
        if attachment.instance != expected_instance || attachment.device_index != new_resource.device_index
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
    
  def wait_for_eni_status(eni, expected_status)
    initial_status = eni.status
    log_callback = proc {
      Chef::Log.info("waiting for #{new_resource} status to change to #{expected_status}...")
    }

    Retryable.retryable(:tries => 30, :sleep => 2, :on => NetworkInterfaceStatusTimeoutError, :ensure => log_callback) do
      raise NetworkInterfaceStatusTimeoutError.new(new_resource, initial_status, expected_status) if eni.status != expected_status
    end
  end

  def detach(eni)
    attachment = current_attachment(eni)
    instance = attachment.instance
    device   = attachment.device_index

    converge_by "detach #{new_resource} from #{new_resource.machine} (#{instance.instance_id})" do
      eni.detach
    end

    converge_by "wait for #{new_resource} to detach" do
      wait_for_eni_status(eni, :available)
      eni
    end
  end

  def attach(eni)
    converge_by "attach #{new_resource} to #{new_resource.machine} (#{expected_instance.instance_id})" do
      options = {}
      options[:device_index] = new_resource.device_index if !new_resource.device_index.nil?
      eni.attach(expected_instance, options)
    end

    converge_by "wait for #{new_resource} to attach" do
      wait_for_eni_status(eni, :in_use)
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

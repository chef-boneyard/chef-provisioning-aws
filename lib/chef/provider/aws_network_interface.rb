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
    #     raise "#{new_resource}.subnet is #{new_resource.subnet}, but actual eni has subnet set to #{eni.subnet}.  Cannot be modified!"
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

  def update_attachment(eni)
    # status = volume.status
    # #
    # # If we were told to attach the volume to a machine, do so
    # #
    # if expected_instance.is_a?(AWS::EC2::Instance)
    #   case status
    #   when :in_use
    #     # We don't want to attempt to reattach to the same instance and device
    #     attachment = current_attachment(volume)
    #     if attachment.instance != expected_instance || attachment.device != new_resource.device
    #       detach(volume)
    #       attach(volume)
    #     end
    #   when :available
    #     attach(volume)
    #   when nil
    #     raise VolumeNotFoundError.new(new_resource)
    #   else
    #     raise VolumeInvalidStatusError.new(new_resource, status)
    #   end

    # #
    # # If we were told to set the machine to false, detach it.
    # #
    # else
    #   case status
    #   when nil
    #     Chef::Log.warn VolumeNotFoundError.new(new_resource)
    #   when :in_use
    #     detach(volume)
    #   end
    # end
    # volume
  end
    
  def wait_for_eni_status(eni, expected_status)
    initial_status = eni.status
    log_callback = proc {
      Chef::Log.info("waiting for #{new_resource} status to change to #{expected_status}...")
    }

    Retryable.retryable(:tries => 30, :sleep => 2, :on => NetworkInterfaceStatusTimeoutError, :ensure => log_callback) do
      raise NetworkInterfaceTimeoutError.new(new_resource, initial_status, expected_status) if eni.status != expected_status
    end
  end

  # def detach(volume)
  #   attachment = current_attachment(volume)
  #   instance = attachment.instance
  #   device   = attachment.device

  #   converge_by "detach #{new_resource} from #{new_resource.machine} (#{instance.instance_id})" do
  #     volume.detach_from(instance, device)
  #   end

  #   converge_by "wait for #{new_resource} to detach" do
  #     wait_for_volume_status(volume, :available)
  #     volume
  #   end
  # end

  # def attach(volume)
  #   converge_by "attach #{new_resource} to #{new_resource.machine} (#{expected_instance.instance_id}) to device #{new_resource.device}" do
  #     volume.attach_to(expected_instance, new_resource.device)
  #   end

  #   converge_by "wait for #{new_resource} to attach" do
  #     wait_for_volume_status(volume, :in_use)
  #     volume
  #   end
  # end

  # def current_attachment(volume)
  #   volume.attachments.first
  # end

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

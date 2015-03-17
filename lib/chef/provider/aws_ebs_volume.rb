require 'chef/provisioning/aws_driver/aws_provider'
require 'cheffish'
require 'date'
require 'retryable'

class Chef::Provider::AwsEbsVolume < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    aws_object = new_resource.aws_object
    status = aws_object ? aws_object.status : nil
    if status == :deleted || status == :deleting
      Chef::Log.warn "#{new_resource} was associated with EBS volume #{aws_object.id}, which is now in #{status} state.  Replacing it ..."
      status = nil
    end
    case status
    when nil
      converge_by "Creating new EBS volume #{new_resource.name} in #{region}" do

        options = {}
        options[:availability_zone] = new_resource.availability_zone if new_resource.availability_zone
        options[:size] = new_resource.size if new_resource.size
        options[:snapshot_id] = new_resource.snapshot if new_resource.snapshot
        options[:iops] = new_resource.iops if new_resource.iops
        options[:volume_type] = new_resource.volume_type if new_resource.volume_type
        options[:encrypted] = new_resource.encrypted if !new_resource.encrypted.nil?

        aws_object = driver.ec2.volumes.create(AWSResource.lookup_options(options, resource: new_resource))
        aws_object.tags['Name'] = new_resource.name
      end

      converge_by "Waiting for new EBS volume #{new_resource.name} in #{region} to become available" do
        wait_for_volume_status(aws_object, :available)
      end
    when :error
      raise "EBS volume #{new_resource.name} (#{aws_object.id}) is in :error state!"
    end
    new_resource.save_managed_entry(aws_object, action_handler)
  end

  action :delete do
    aws_object = new_resource.aws_object
    status = aws_object ? aws_object.status : nil
    case status
    when nil, :deleted, :deleting
    when :in_use
      current_attachment = aws_object.attachments.first
      instance = Chef::Resource::AwsInstance.get_aws_object(new_resource.machine, resource: new_resource)
      Chef::Log.info("EBS volume #{new_resource.name} (#{aws_object.id}) is attached to instance #{current_attachment.instance.id}. Detaching from instance #{instance.id}.")
      detach(:instance => current_attachment.instance, :device => current_attachment.device)
      delete
    else
      delete
    end
    new_resource.delete_managed_entry(action_handler)
  end

  action :attach do
    aws_object = new_resource.aws_object
    status = aws_object ? aws_object.status : nil
    case status
    when :in_use
      current_attachment = aws_object.attachments.first
      instance = Chef::Resource::AwsInstance.get_aws_object(new_resource.machine, resource: new_resource)
      # wrong instance
      if current_attachment.instance != instance
        Chef::Log.info("EBS volume #{new_resource.name} (#{aws_object.id}) is attached to instance #{current_attachment.instance.id}. Reattaching to instance #{instance.id} to device #{new_resource.device}.")
        detach(:instance => current_attachment.instance, :device => current_attachment.device)
        attach
      # wrong device only
      elsif current_attachment.instance == instance and current_attachment.device != new_resource.device
        Chef::Log.info("EBS volume #{new_resource.name} (#{aws_object.id}) is attached to instance #{current_attachment.instance.id} on device #{current_attachment.device}. Reattaching device to #{new_resource.device}.")
        detach(:device => current_attachment.device)
        attach
      else
        Chef::Log.info("EBS volume #{new_resource.name} (#{aws_object.id}) is properly attached to instance #{current_attachment.instance.id} on device #{current_attachment.device}.")
      end
    when :available
      attach
    when nil
      raise "EBS volume #{new_resource.name} does not currently exist!"
    else
      raise "EBS volume #{new_resource.name} (#{aws_object.id}) is in #{status} state!"
    end
    new_resource.save_managed_entry(aws_object, action_handler)
  end

  action :detach do
    aws_object = new_resource.aws_object
    status = aws_object ? aws_object.status : nil
    case status
    when nil
      Chef::Log.warn "EBS volume #{new_resource.name} does not currently exist!"
    when :in_use
      detach
    end
    new_resource.save_managed_entry(aws_object, action_handler)
  end

  private

  def wait_for_volume_status(volume, status)
    log_callback = Proc.new do
      Chef::Log.info("Waiting for volume status to change to #{status.to_s}...")
    end

    Retryable.retryable(:tries => 30, :sleep => 2, :on => TimeoutError, :ensure => log_callback) do
      raise TimeoutError,
        "Timed out waiting for volume status to change to #{status.to_s}!" if volume.status != status
    end
  end

  def detach(options = {})
    aws_object = new_resource.aws_object
    current_instance = options[:instance] || Chef::Resource::AwsInstance.get_aws_object(new_resource.machine, resource: new_resource)
    current_device   = options[:device] || aws_object.attachments.first.device

    converge_by "Detaching EBS volume #{new_resource.name} in #{region}" do
      aws_object.detach_from(current_instance, current_device)
    end

    converge_by "Waiting for EBS volume #{new_resource.name} in #{region} to detach" do
      wait_for_volume_status(aws_object, :available)
    end
  end

  def attach
    aws_object = new_resource.aws_object
    options = {}
    options[:device] = new_resource.device if new_resource.device

    converge_by "Attaching EBS volume #{new_resource.name} in #{region}" do
      aws_object.attach_to(Chef::Resource::AwsInstance.get_aws_object(new_resource.machine, resource: new_resource), new_resource.device)
    end

    converge_by "Waiting for EBS volume #{new_resource.name} in #{region} to attach" do
      wait_for_volume_status(aws_object, :in_use)
    end
  end

  def delete
    aws_object = new_resource.aws_object
    converge_by "Deleting EBS volume #{new_resource.name} in #{region}" do
      aws_object.delete
    end

    converge_by "Waiting for EBS volume #{new_resource.name} in #{region} to delete" do
      log_callback = Proc.new do
        Chef::Log.info("Waiting for volume to delete...")
      end

      Retryable.retryable(:tries => 30, :sleep => 2, :on => TimeoutError, :ensure => log_callback) do
        raise TimeoutError,
          "Timed out waiting for EBS volume #{new_resource.name} (#{aws_object.id}) to delete!" if aws_object.exists?
      end
    end
  end
end

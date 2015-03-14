require 'chef/provisioning/aws_driver/aws_provider'
require 'cheffish'
require 'date'
require 'chef/provisioning/aws_driver/mixin/aws_instance'

class Chef::Provider::AwsEbsVolume < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::Mixin::AWSInstance

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
        wait_for_volume_status :available
      end
    when :error
      raise "EBS volume #{new_resource.name} (#{aws_object.volume_id}) is in :error state!"
    end
    new_resource.save_managed_entry(aws_object, action_handler)
  end

  action :delete do
    aws_object = new_resource.aws_object
    status = aws_object ? aws_object.status : nil
    case status
    when nil, :deleted, :deleting
    else
      converge_by "Deleting EBS volume #{new_resource.name} in #{region}" do
        aws_object.delete
      end

      converge_by "Waiting for EBS volume #{new_resource.name} in #{region} to delete" do
        log_callback = Proc.new do
          Chef::Log.debug("Waiting for volume to delete...")
        end

        Retryable.retryable(:tries => 30, :sleep => 2, :on => TimeoutError, :ensure => log_callback) do
          raise TimeoutError,
            "Timed out waiting for EBS volume #{new_resource.name} (#{aws_object.volume_id}) to delete!" if aws_object.exists?
        end
      end
    end
    new_resource.delete_managed_entry(action_handler)
  end

  action :attach do
    aws_object = new_resource.aws_object
    status = aws_object ? aws_object.status : raise "EBS volume #{new_resource.name} does not currently exist!"
    case status
    when :in_use
      expected_attachment = aws_object.attachments.find do |attachment|
        attachment.instance == instance &&
        attachment.device == new_resource.device
      end

      if not expected_attachment
        detach
        attach
      end
    when :available
      attach
    else
      raise "EBS volume #{new_resource.name} (#{aws_object.volume_id}) is in #{status} state!"
    end
    new_resource.save_managed_entry(aws_object, action_handler)
  end

  action :detach do
    aws_object = new_resource.aws_object
    status = aws_object ? aws_object.status : Chef::Log.warn "EBS volume #{new_resource.name} does not currently exist!"
    case status
    when :in_use
      detach
    end
    new_resource.save_managed_entry(aws_object, action_handler)
  end

  private

  def wait_for_volume_status(status)
    log_callback = Proc.new do
      Chef::Log.debug("Waiting for volume status: #{status.to_s}...")
    end

    Retryable.retryable(:tries => 30, :sleep => 2, :on => TimeoutError, :ensure => log_callback) do
      raise TimeoutError,
        "Timed out waiting for volume status: #{status.to_s}!" if aws_object.status != status
    end
  end

  def detach
    options = {}
    options[:device] = new_resource.device if new_resource.device

    converge_by "Detaching EBS volume #{new_resource.name} in #{region}" do
      aws_object.detach_from(instance, AWSResource.lookup_options(options, resource: new_resource))
    end

    converge_by "Waiting for EBS volume #{new_resource.name} in #{region} to detach" do
      wait_for_volume_status :available
    end
  end

  def attach
    options = {}
    options[:device] = new_resource.device if new_resource.device

    converge_by "Attaching EBS volume #{new_resource.name} in #{region}" do
      aws_object.attach_to(instance, AWSResource.lookup_options(options, resource: new_resource))
    end

    converge_by "Waiting for EBS volume #{new_resource.name} in #{region} to attach" do
      wait_for_volume_status :in_use
    end
  end
end

require 'chef/provisioning/aws_driver/aws_provider'
require 'cheffish'
require 'date'
require 'retryable'

class Chef::Provider::AwsEbsVolume < Chef::Provisioning::AWSDriver::AWSProvider
  def action_create
    volume = super

    if !new_resource.machine.nil?
      update_attachment(volume)
    end
  end

  protected

  def create_aws_object
    volume = nil
    converge_by "create new EBS volume #{new_resource.name} in #{region}" do
      volume = new_resource.driver.ec2.volumes.create(desired_options)
      volume.tags['Name'] = new_resource.name
    end

    converge_by "wait for new EBS volume #{new_resource.name} in #{region} to become available" do
      wait_for_volume_status(volume, :available)
      volume
    end
  end

  def update_aws_object(volume)
    if desired_options.has_key?(:availability_zone)
      if desired_options[:availability_zone] != volume.availability_zone_name
        raise "#{new_resource.to_s}.availability_zone is #{new_resource.availability_zone}, but actual volume has availability_zone_name set to #{volume.availability_zone_name}.  Cannot be modified!"
      end
    end
    if desired_options.has_key?(:size)
      if desired_options[:size] != volume.size
        raise "#{new_resource.to_s}.size is #{new_resource.size}, but actual volume has size set to #{volume.size}.  Cannot be modified!"
      end
    end
    if desired_options.has_key?(:snapshot)
      if desired_options[:snapshot] != snapshot.id
        raise "#{new_resource.to_s}.snapshot is #{new_resource.snapshot}, but actual volume has snapshot set to #{volume.snapshot.id}.  Cannot be modified!"
      end
    end
    if desired_options.has_key?(:iops)
      if desired_options[:iops] != volume.iops
        raise "#{new_resource.to_s}.iops is #{new_resource.iops}, but actual volume has iops set to #{volume.iops}.  Cannot be modified!"
      end
    end
    if desired_options.has_key?(:volume_type)
      if desired_options[:volume_type] != volume.type
        raise "#{new_resource.to_s}.volume_type is #{new_resource.volume_type}, but actual volume has type set to #{volume.type}.  Cannot be modified!"
      end
    end
    if desired_options.has_key?(:encrypted)
      if desired_options[:encrypted] != !!volume.encrypted
        raise "#{new_resource.to_s}.encrypted is #{new_resource.encrypted}, but actual volume has encrypted set to #{volume.encrypted}.  Cannot be modified!"
      end
    end
  end

  def destroy_aws_object(volume)
    status = volume.status
    case status
    when :in_use
      attachment = volume.attachments.first
      detach(volume, :instance => attachment.instance, :device => attachment.device)
      delete(volume)
    else
      delete(volume)
    end
  end

  private

  def desired_instance
    if !defined?(@desired_instance)
      if new_resource.machine == false
        @desired_instance = nil
      else
        @desired_instance = Chef::Resource::AwsInstance.get_aws_object(new_resource.machine, resource: new_resource)
      end
    end
    @desired_instance
  end

  def desired_options
    @desired_options ||= begin
      options = {}
      options[:availability_zone] = new_resource.availability_zone if !new_resource.availability_zone.nil?
      options[:size]              = new_resource.size              if !new_resource.size.nil?
      options[:snapshot_id]       = new_resource.snapshot          if !new_resource.snapshot.nil?
      options[:iops]              = new_resource.iops              if !new_resource.iops.nil?
      options[:volume_type]       = new_resource.volume_type       if !new_resource.volume_type.nil?
      options[:encrypted]         = new_resource.encrypted         if !new_resource.encrypted.nil?
      options[:encrypted] = !!options[:encrypted] if !options[:encrypted].nil?

      AWSResource.lookup_options(options, resource: new_resource)
    end
  end

  def update_attachment(volume)
    status = volume.status
    #
    # If we were told to attach the volume to a machine, do so
    #
    if desired_instance.is_a?(AWS::EC2::Instance)
      case status
      when :in_use
        attachment = volume.attachments.first
        # wrong instance
        if attachment.instance != desired_instance
          detach(volume, :instance => attachment.instance, :device => attachment.device)
          attach(volume)
        # wrong device only
        elsif attachment.instance == desired_instance && attachment.device != new_resource.device
          detach(volume, :device => attachment.device)
          attach(volume)
        end

      when :available
        attach(volume)
      when nil
        raise "EBS volume #{new_resource.name} does not currently exist!"
      else
        raise "EBS volume #{new_resource.name} (#{volume.id}) is in #{status} state!"
      end

    #
    # If we were told to set the machine to false, detach it.
    #
    else
      case status
      when nil
        Chef::Log.warn "EBS volume #{new_resource.name} does not currently exist!"
      when :in_use
        attachment = volume.attachments.first
        detach(volume, :instance => attachment.instance, :device => attachment.device)
      end
    end
    volume
  end
    
  def wait_for_volume_status(volume, status)
    log_callback = proc {
      Chef::Log.info("waiting for volume status to change to #{status}...")
    }

    Retryable.retryable(:tries => 30, :sleep => 2, :on => TimeoutError, :ensure => log_callback) do
      raise TimeoutError,
        "timed out waiting for volume status to change from #{volume.status} to #{status}!" if volume.status != status
    end
  end

  def detach(volume, options = {})
    instance = options[:instance] || desired_instance
    device   = options[:device] || volume.attachments.first.device

    converge_by "detach EBS volume #{new_resource.name} in #{region} from instance #{new_resource.machine} (#{instance.instance_id})" do
      volume.detach_from(instance, device)
    end

    converge_by "wait for EBS volume #{new_resource.name} in #{region} to detach" do
      wait_for_volume_status(volume, :available)
    end
  end

  def attach(volume)
    converge_by "attach EBS volume #{new_resource.name} in #{region} to instance #{new_resource.machine} (#{desired_instance.instance_id})" do
      volume.attach_to(desired_instance, new_resource.device)
    end

    converge_by "wait for EBS volume #{new_resource.name} in #{region} to attach" do
      wait_for_volume_status(volume, :in_use)
      volume
    end
  end

  def delete(volume)
    converge_by "delete EBS volume #{new_resource.name} in #{region}" do
      volume.delete
    end

    converge_by "wait for EBS volume #{new_resource.name} in #{region} to delete" do
      log_callback = proc {
        Chef::Log.info('waiting for volume to delete...')
      }

      Retryable.retryable(:tries => 30, :sleep => 2, :on => TimeoutError, :ensure => log_callback) do
        raise TimeoutError,
          "timed out waiting for EBS volume #{new_resource.name} (#{volume.id}) to delete!" if volume.exists?
      end
    end
  end
end

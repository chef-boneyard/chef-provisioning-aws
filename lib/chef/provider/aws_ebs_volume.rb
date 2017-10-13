require 'chef/provisioning/aws_driver/aws_provider'
require 'cheffish'
require 'date'
require 'retryable'

class Chef::Provider::AwsEbsVolume < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::EC2ConvergeTags

  provides :aws_ebs_volume

  class VolumeNotFoundError < RuntimeError
    def initialize(new_resource)
      super("#{new_resource} does not exist!")
    end
  end

  class VolumeStatusTimeoutError < ::Timeout::Error
    def initialize(new_resource, initial_status, expected_status)
      super("timed out waiting for #{new_resource} status to change from #{initial_status} to #{expected_status}!")
    end
  end

  class VolumeInvalidStatusError < RuntimeError
    def initialize(new_resource, status)
      super("#{new_resource} is in #{status} state!")
    end
  end

  def action_create
    volume = super

    if !new_resource.machine.nil?
      update_attachment(volume)
    end
  end

  protected

  def create_aws_object
    volume = nil
    converge_by "create #{new_resource} in #{region}" do
      volume = new_resource.driver.ec2_resource.create_volume(initial_options)
      retry_with_backoff(::Aws::EC2::Errors::InvalidVolumeNotFound) do
        new_resource.driver.ec2_resource.create_tags(resources: [volume.volume_id],tags: [{key: "Name", value: new_resource.name}])
      end
      volume
    end

    converge_by "wait for new #{new_resource} in #{region} to become available" do
      wait_for_volume_status(volume, :available)
      volume
    end
  end

  def update_aws_object(volume)
    if initial_options.has_key?(:availability_zone)
      if availability_zone != volume.availability_zone
        raise "#{new_resource}.availability_zone is #{availability_zone}, but actual volume has availability_zone_name set to #{volume.availability_zone}.  Cannot be modified!"
      end
    end
    if initial_options.has_key?(:size)
      if initial_options[:size] != volume.size
        raise "#{new_resource}.size is #{new_resource.size}, but actual volume has size set to #{volume.size}.  Cannot be modified!"
      end
    end
    if initial_options.has_key?(:snapshot_id)
      if initial_options[:snapshot_id] != volume.snapshot_id
        raise "#{new_resource}.snapshot is #{new_resource.snapshot}, but actual volume has snapshot set to #{volume.snapshot_id}.  Cannot be modified!"
      end
    end
    if initial_options.has_key?(:iops)
      if initial_options[:iops] != volume.iops
        raise "#{new_resource}.iops is #{new_resource.iops}, but actual volume has iops set to #{volume.iops}.  Cannot be modified!"
      end
    end
    if initial_options.has_key?(:volume_type)
      if initial_options[:volume_type] != volume.volume_type
        raise "#{new_resource}.volume_type is #{new_resource.volume_type}, but actual volume has type set to #{volume.type}.  Cannot be modified!"
      end
    end
    if initial_options.has_key?(:encrypted)
      if initial_options[:encrypted] != !!volume.encrypted
        raise "#{new_resource}.encrypted is #{new_resource.encrypted}, but actual volume has encrypted set to #{volume.encrypted}.  Cannot be modified!"
      end
    end
  end

  def destroy_aws_object(volume)
    detach(volume) if volume.state == "in-use"
    delete(volume)
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
      options[:availability_zone] = availability_zone              if !new_resource.availability_zone.nil?
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
    status = new_resource.driver.ec2_resource.volume(volume.id).state
    #
    # If we were told to attach the volume to a machine, do so
    #
    if expected_instance.is_a?(::Aws::EC2::Instance) || expected_instance.is_a?(::Aws::EC2::Instance)
      case status
      when "in-use"
        # We don't want to attempt to reattach to the same instance and device
        attachment = current_attachment(volume)
        if attachment.instance_id != expected_instance.id || attachment.device != new_resource.device
          detach(volume)
          attach(volume)
        end
      when "available"
        attach(volume)
      when nil
        raise VolumeNotFoundError.new(new_resource)
      else
        raise VolumeInvalidStatusError.new(new_resource, status)
      end

    #
    # If we were told to set the machine to false, detach it.
    #
    else
      case status
      when nil
        Chef::Log.warn VolumeNotFoundError.new(new_resource)
      when "in-use"
        detach(volume)
      end
    end
    volume
  end

  def wait_for_volume_status(volume, expected_status)
    log_callback = proc {
      Chef::Log.info("waiting for #{new_resource} status to change to #{expected_status}...")
    }

    Retryable.retryable(:tries => 120, :sleep => 2, :on => VolumeStatusTimeoutError, :ensure => log_callback) do
      status = new_resource.driver.ec2_resource.volume(volume.id).state
      expected_status = "in-use" if expected_status.to_s.eql?("in_use")
      raise VolumeStatusTimeoutError.new(new_resource, status, expected_status) if status != expected_status.to_s
    end
  end

  def detach(volume)
    attachment = current_attachment(volume)
    instance = attachment.instance_id
    device   = attachment.device

    converge_by "detach #{new_resource} from #{new_resource.machine} (#{instance})" do
      volume.detach_from_instance(instance_id: instance, device: device)
    end

    converge_by "wait for #{new_resource} to detach" do
      wait_for_volume_status(volume, :available)
      volume
    end
  end

  def attach(volume)
    converge_by "attach #{new_resource} to #{new_resource.machine} (#{expected_instance.instance_id}) to device #{new_resource.device}" do
      volume.attach_to_instance(instance_id: expected_instance.id, device: new_resource.device)
    end

    converge_by "wait for #{new_resource} to attach" do
      wait_for_volume_status(volume, :in_use)
      volume
    end
  end

  def current_attachment(volume)
    volume.attachments.first
  end

  def delete(volume)
    converge_by "delete #{new_resource} in #{region}" do
      volume.delete
    end

    converge_by "wait for #{new_resource} in #{region} to delete" do
      log_callback = proc {
        Chef::Log.info('waiting for volume to delete...')
      }

      Retryable.retryable(:tries => 30, :sleep => 2, :on => VolumeStatusTimeoutError, :ensure => log_callback) do
        result = new_resource.driver.ec2_resource.volume(volume.id) if volume.id
        raise VolumeStatusTimeoutError.new(new_resource, "exists", "deleted") if new_resource.exists?(result)
      end
      volume
    end
  end

  def availability_zone
    az = new_resource.availability_zone
    if /^#{region}/ =~ az
      Chef::Log.warn("availability_zone attribute should only be set to the letter designation. Attempting to use '#{az[-1]}' to correct the issue.")
    elsif az.length == 1
      az = "#{region}#{az[-1]}"
    end
    az
  end
end

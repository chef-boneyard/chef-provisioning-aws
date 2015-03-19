require 'chef/provisioning/aws_driver/aws_provider'
require 'cheffish'
require 'date'

class Chef::Provider::AwsEbsVolume < Chef::Provisioning::AWSDriver::AWSProvider
  protected

  def create_aws_object
    converge_by "create new EBS volume #{new_resource.name} in #{region}" do
      volume = new_resource.driver.ec2.volumes.create(desired_options)
      volume.tags['Name'] = new_resource.name
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
    converge_by "delete EBS volume #{new_resource.name} in #{region}" do
      volume.delete
    end
  end

  private

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
end

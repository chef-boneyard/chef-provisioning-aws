require 'chef/provisioning/aws_driver/aws_provider'
require 'cheffish'
require 'date'

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
      # TODO wait until deleted?
    end
    new_resource.delete_managed_entry(action_handler)
  end
end

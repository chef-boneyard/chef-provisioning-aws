require 'chef/provisioning/aws_driver/aws_provider'
require 'cheffish'
require 'date'

class Chef::Provider::AwsEbsVolume < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    if !aws_object
      converge_by "Creating new EBS volume #{new_resource.name} in #{region}" do

        options = {}
        options[:availability_zone] = new_resource.availability_zone if new_resource.availability_zone
        options[:size] = new_resource.size if new_resource.size
        options[:snapshot_id] = new_resource.snapshot if new_resource.snapshot
        options[:iops] = new_resource.iops if new_resource.iops
        options[:volume_type] = new_resource.volume_type if new_resource.volume_type
        options[:encrypted] = new_resource.encrypted if !new_resource.encrypted.nil?

        ebs = aws_driver.ec2.volumes.create(managed_aws.lookup_options(options))
        ebs.tags['Name'] = new_resource.name

        save_managed_entry(id: ebs.id)
      end
    end
  end

  action :delete do
    if aws_object
      converge_by "Deleting EBS volume #{new_resource.name} in #{region}" do
        aws_object.delete
      end
    end
    delete_spec
  end

  def aws_object
    @aws_object ||= begin
      volume = super
      if volume && ![:deleted, :deleting, :error].include?(volume.status)
        volume
      else
        nil
      end
    end
  end
end

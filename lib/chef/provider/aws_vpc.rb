require 'chef/provisioning/aws_driver/aws_provider'
require 'date'

class Chef::Provider::AwsVpc < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    fail "Can't create a VPC without a CIDR block" if new_resource.cidr_block.nil?

    aws_object = new_resource.aws_object
    if !aws_object
      converge_by "Creating new VPC #{new_resource.name} in #{region}" do
        opts = { :instance_tenancy => new_resource.instance_tenancy }
        vpc = driver.ec2.vpcs.create(new_resource.cidr_block, opts)
        vpc.tags['Name'] = new_resource.name
        new_resource.save_managed_entry(vpc, action_handler)
      end
    end
  end

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      converge_by "Deleting VPC #{aws_object.id} in #{region}" do
        aws_object.delete
      end
    end

    new_resource.delete_managed_entry(action_handler)
  end

end

require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsVpc < Chef::Provider::AwsProvider

  action :create do
    fail "Can't create a VPC without a CIDR block" if new_resource.cidr_block.nil?

    if !aws_object
      converge_by "Creating new VPC #{new_resource.name} in #{region}" do
        opts = { :instance_tenancy => new_resource.instance_tenancy }
        vpc = aws_driver.ec2.vpcs.create(new_resource.cidr_block, opts)
        vpc.tags['Name'] = new_resource.name
        save_managed_entry(id: vpc.id)
      end
    end
  end

  action :delete do
    if aws_object
      converge_by "Deleting VPC #{aws_object.id} in #{region}" do
        aws_object.delete
      end
    end

    delete_managed_entry
  end

end

require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsVpc < Chef::Provider::AwsProvider

  action :create do
    fail "Can't create a VPC without a CIDR block" if new_resource.cidr_block.nil?

    if existing_vpc == nil
      converge_by "Creating new VPC #{fqn} in #{new_resource.region_name}" do
        opts = { :instance_tenancy => :default}
        vpc = ec2.vpcs.create(new_resource.cidr_block, opts)
        vpc.tags['Name'] = new_resource.name
        new_resource.vpc_id vpc.id
        new_resource.save
      end
    end
  end

  action :delete do
    if existing_vpc
      converge_by "Deleting VPC #{fqn} in #{new_resource.region_name}" do
        existing_vpc.delete
      end
    end

    new_resource.delete
  end

  def existing_vpc
    @existing_vpc ||= begin
      ec2.vpcs.with_tag('Name', new_resource.name).first
    rescue
      nil
    end
  end

  def id
    new_resource.vpc_id
  end

end

require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsSubnet < Chef::Provider::AwsProvider

  action :create do
    fail "Can't create a Subnet without a CIDR block" if new_resource.cidr_block.nil?

    if existing_subnet == nil
      converge_by "Creating new Subnet #{fqn} in VPC #{new_resource.vpc} in #{new_resource.region_name}" do
        opts = { :vpc => vpc_id }
	opts[:availability_zone] = new_resource.availability_zone if new_resource.availability_zone
        subnet = ec2.subnets.create(new_resource.cidr_block, opts)
        subnet.tags['Name'] = new_resource.name
        subnet.tags['VPC'] = new_resource.vpc
        new_resource.subnet_id subnet.id
        new_resource.save
      end
    end
  end

  action :delete do
    if existing_subnet
      converge_by "Deleting subnet #{fqn} in VPC #{new_resource.vpc} in #{new_resource.region_name}" do
        existing_subnet.delete
      end
    end

    new_resource.delete
  end

  def vpc_id
    @vpc_id ||= begin
      ec2.vpcs.with_tag('Name', new_resource.vpc).first
    rescue
      nil
    end
  end

  def existing_subnet
      @subnet_id ||= begin
      ec2.subnets.with_tag('Name', new_resource.name).first
    rescue
      nil
    end
  end

  def id
    new_resource.subnet_id
  end

end

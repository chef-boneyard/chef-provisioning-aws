require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsSubnet < Chef::Provider::AwsProvider

  action :create do
    fail "Can't create a Subnet without a CIDR block" if new_resource.cidr_block.nil?

    if existing_subnet
      subnet = existing_subnet
      # TODO update things
    else
      converge_by "Creating new Subnet #{fqn} in VPC #{new_resource.vpc} in #{new_driver.aws_config.region}" do
        opts = { :vpc => vpc_id }
        opts[:availability_zone] = new_resource.availability_zone if new_resource.availability_zone
        subnet = new_driver.ec2.subnets.create(new_resource.cidr_block, opts)
        subnet.tags['Name'] = new_resource.name
        subnet.tags['VPC'] = new_resource.vpc
        new_resource.subnet_id subnet.id
        new_resource.save
      end
    end

    subnet_desc = new_driver.ec2.client.describe_subnets(subnet_ids: [ subnet.id ])[:subnet_set].first
    if new_resource.map_public_ip_on_launch
      if !subnet_desc[:map_public_ip_on_launch]
        converge_by "Turning on automatic public IPs for subnet #{subnet.id}" do
          new_driver.ec2.client.modify_subnet_attribute(subnet_id: subnet.id, map_public_ip_on_launch: { value: true })
        end
      end
    else
      if subnet_desc[:map_public_ip_on_launch]
        converge_by "Turning off automatic public IPs for subnet #{subnet.id}" do
          new_driver.ec2.client.modify_subnet_attribute(subnet_id: subnet.id, map_public_ip_on_launch: { value: false })
        end
      end
    end
  end

  action :delete do
    if existing_subnet
      converge_by "Deleting subnet #{fqn} in VPC #{new_resource.vpc} in #{new_driver.aws_config.region}" do
        existing_subnet.delete
      end
    end

    new_resource.delete
  end

  def vpc_id
    @vpc_id ||= begin
      new_driver.ec2.vpcs.with_tag('Name', new_resource.vpc).first
    rescue
      nil
    end
  end

  def existing_subnet
    @existing_subnet ||= begin
      new_driver.ec2.subnets.with_tag('Name', new_resource.name).first
    rescue
      nil
    end
  end

  def id
    new_resource.subnet_id
  end

end

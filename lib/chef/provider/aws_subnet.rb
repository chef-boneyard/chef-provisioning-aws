require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/aws_resource'
require 'date'
require 'chef/resource/aws_vpc'

class Chef::Provider::AwsSubnet < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    aws_object = new_resource.aws_object
    if !aws_object
      cidr_block = new_resource.cidr_block
      if !cidr_block
        cidr_block = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource).cidr_block
      end
      converge_by "Creating new Subnet #{new_resource.name} with CIDR #{cidr_block} in VPC #{new_resource.vpc} in #{region}" do
        opts = { :vpc => new_resource.vpc }
        opts[:availability_zone] = new_resource.availability_zone if new_resource.availability_zone
        opts = Chef::Provisioning::AWSDriver::AWSResource.lookup_options(opts, resource: new_resource)
        subnet = driver.ec2.subnets.create(cidr_block, opts)
        subnet.tags['Name'] = new_resource.name
        subnet.tags['VPC'] = new_resource.vpc
        new_resource.save_managed_entry(subnet, action_handler)
        aws_object = subnet
      end
    end

    if !new_resource.map_public_ip_on_launch.nil?
      subnet_desc = driver.ec2.client.describe_subnets(subnet_ids: [ aws_object.id ])[:subnet_set].first
      if new_resource.map_public_ip_on_launch
        if !subnet_desc[:map_public_ip_on_launch]
          converge_by "Turning on automatic public IPs for subnet #{aws_object.id}" do
            driver.ec2.client.modify_subnet_attribute(subnet_id: aws_object.id, map_public_ip_on_launch: { value: true })
          end
        end
      else
        if subnet_desc[:map_public_ip_on_launch]
          converge_by "Turning off automatic public IPs for subnet #{aws_object.id}" do
            driver.ec2.client.modify_subnet_attribute(subnet_id: aws_object.id, map_public_ip_on_launch: { value: false })
          end
        end
      end
    end
  end

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      converge_by "Deleting subnet #{new_resource.name} in VPC #{new_resource.vpc} in #{region}" do
        aws_object.delete
      end
    end

    new_resource.delete_managed_entry(action_handler)
  end

end

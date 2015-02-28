require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsSubnet < Chef::Provider::AwsProvider

  action :create do
    if !current_aws_object
      cidr_block = new_resource.cidr_block
      if !cidr_block
        cidr_block = managed_aws.get_aws_object(:vpc, new_resource.vpc).cidr_block
      end
      converge_by "Creating new Subnet #{new_resource.name} with CIDR #{cidr_block} in VPC #{new_resource.vpc} in #{region}" do
        opts = { :vpc => new_resource.vpc }
        opts[:availability_zone] = new_resource.availability_zone if new_resource.availability_zone
        opts = managed_aws.lookup_options(opts)
        subnet = new_driver.ec2.subnets.create(cidr_block, opts)
        subnet.tags['Name'] = new_resource.name
        subnet.tags['VPC'] = new_resource.vpc
        save_entry(id: subnet.id)
        @current_aws_object = subnet
      end
    end

    if !new_resource.map_public_ip_on_launch.nil?
      subnet_desc = new_driver.ec2.client.describe_subnets(subnet_ids: [ current_aws_object.id ])[:subnet_set].first
      if new_resource.map_public_ip_on_launch
        if !subnet_desc[:map_public_ip_on_launch]
          converge_by "Turning on automatic public IPs for subnet #{current_aws_object.id}" do
            new_driver.ec2.client.modify_subnet_attribute(subnet_id: current_aws_object.id, map_public_ip_on_launch: { value: true })
          end
        end
      else
        if subnet_desc[:map_public_ip_on_launch]
          converge_by "Turning off automatic public IPs for subnet #{current_aws_object.id}" do
            new_driver.ec2.client.modify_subnet_attribute(subnet_id: current_aws_object.id, map_public_ip_on_launch: { value: false })
          end
        end
      end
    end
  end

  action :delete do
    if current_aws_object
      converge_by "Deleting subnet #{new_resource.name} in VPC #{new_resource.vpc} in #{region}" do
        current_aws_object.delete
      end
    end

    delete_entry
  end

end

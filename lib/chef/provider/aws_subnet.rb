require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/aws_resource'
require 'date'
require 'chef/resource/aws_vpc'

class Chef::Provider::AwsSubnet < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    subnet = new_resource.aws_object
    if subnet
      update_subnet(subnet)
    else
      subnet = create_subnet
    end

    new_resource.save_managed_entry(subnet, action_handler)

    if new_resource.map_public_ip_on_launch != nil
      update_map_public_ip_on_launch(subnet)
    end

    if new_resource.route_table != nil
      update_route_table(subnet)
    end
  end

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      converge_by "delete subnet #{new_resource.name} in VPC #{new_resource.vpc} in #{region}" do
        aws_object.delete
      end
    end

    new_resource.delete_managed_entry(action_handler)
  end

  private

  def create_subnet
    cidr_block = new_resource.cidr_block
    if !cidr_block
      cidr_block = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource).cidr_block
    end
    options = { :vpc => new_resource.vpc }
    options[:availability_zone] = new_resource.availability_zone if new_resource.availability_zone
    options = Chef::Provisioning::AWSDriver::AWSResource.lookup_options(options, resource: new_resource)

    subnet = nil
    converge_by "create new subnet #{new_resource.name} with CIDR #{cidr_block} in VPC #{new_resource.vpc} (#{options[:vpc]}) in #{region}" do
      subnet = driver.ec2.subnets.create(cidr_block, options)
      subnet.tags['Name'] = new_resource.name
      subnet.tags['VPC'] = new_resource.vpc
      aws_object = subnet
    end

    subnet
  end

  def update_subnet(subnet)
    # Verify unmodifiable attributes of existing subnet
    if new_resource.cidr_block && subnet.cidr_block != new_resource.cidr_block
      raise "cidr_block for subnet #{new_resource.name} is #{new_resource.cidr_block}, but existing subnet (#{subnet.id})'s cidr_block is #{new_resource.cidr_block}.  Modification of subnet cidr_block is unsupported!"
    end
    vpc = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource)
    if vpc && subnet.vpc != vpc
      raise "vpc for subnet #{new_resource.name} is #{new_resource.vpc} (#{vpc.id}), but existing subnet (#{subnet.id})'s vpc is #{subnet.vpc.id}.  Modification of subnet vpc is unsupported!"
    end
    if new_resource.availability_zone && subnet.availability_zone != new_resource.availability_zone
      raise "availability_zone for subnet #{new_resource.name} is #{new_resource.availability_zone}, but existing subnet (#{subnet.id})'s availability_zone is #{new_resource.availability_zone}.  Modification of subnet availability_zone is unsupported!"
    end
  end

  def update_map_public_ip_on_launch(subnet)
    if !new_resource.map_public_ip_on_launch.nil?
      subnet_desc = driver.ec2.client.describe_subnets(subnet_ids: [ subnet.id ])[:subnet_set].first
      if new_resource.map_public_ip_on_launch
        if !subnet_desc[:map_public_ip_on_launch]
          converge_by "turn on automatic public IPs for subnet #{subnet.id}" do
            driver.ec2.client.modify_subnet_attribute(subnet_id: subnet.id, map_public_ip_on_launch: { value: true })
          end
        end
      else
        if subnet_desc[:map_public_ip_on_launch]
          converge_by "turn off automatic public IPs for subnet #{subnet.id}" do
            driver.ec2.client.modify_subnet_attribute(subnet_id: subnet.id, map_public_ip_on_launch: { value: false })
          end
        end
      end
    end
  end

  def update_route_table(subnet)
    if new_resource.route_table == :default_to_main
      if !subnet.route_table_association.main?
        converge_by "reset route table of subnet #{new_resource.name} to the VPC default" do
          subnet.route_table = nil
        end
      end
    else
      route_table = Chef::Resource::AwsRouteTable.get_aws_object(new_resource.route_table, resource: new_resource)
      current_route_table_association = subnet.route_table_association
      if current_route_table_association.main?
        # Even if the user sets the route table explicitly to the main route table,
        # we have work to do here: we need to make the relationship explicit so that
        # it won't be changed when the main route table of the VPC changes.
        converge_by "set route table of subnet #{new_resource.name} to #{new_resource.route_table}" do
          subnet.route_table = route_table
        end
      elsif current_route_table_association.route_table != route_table
        # The route table is different now.  Change it.
        converge_by "change route table of subnet #{new_resource.name} to #{new_resource.route_table} (was #{current_route_table_association.route_table.id})" do
          subnet.route_table = route_table
        end
      end
    end
  end
end

require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/aws_resource'
require 'date'
require 'chef/resource/aws_vpc'

class Chef::Provider::AwsSubnet < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::EC2ConvergeTags

  provides :aws_subnet

  def action_create
    subnet = super

    if new_resource.map_public_ip_on_launch != nil
      update_map_public_ip_on_launch(subnet)
    end

    if new_resource.route_table != nil
      update_route_table(subnet)
    end

    update_network_acl(subnet)
  end

  protected

  def create_aws_object
    cidr_block = new_resource.cidr_block
    if !cidr_block
      cidr_block = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource).cidr_block
    end
    options = { :vpc => new_resource.vpc }
    options[:availability_zone] = new_resource.availability_zone if new_resource.availability_zone
    options = Chef::Provisioning::AWSDriver::AWSResource.lookup_options(options, resource: new_resource)

    converge_by "create subnet #{new_resource.name} with CIDR #{cidr_block} in VPC #{new_resource.vpc} (#{options[:vpc]}) in #{region}" do
      subnet = new_resource.driver.ec2.subnets.create(cidr_block, options)
      retry_with_backoff(AWS::EC2::Errors::InvalidSubnetID::NotFound) do
        subnet.tags['Name'] = new_resource.name
        subnet.tags['VPC'] = new_resource.vpc
      end
      subnet
    end
  end

  def update_aws_object(subnet)
    # Verify unmodifiable attributes of existing subnet
    if new_resource.cidr_block && subnet.cidr_block != new_resource.cidr_block
      raise "cidr_block for subnet #{new_resource.name} is #{new_resource.cidr_block}, but existing subnet (#{subnet.id})'s cidr_block is #{subnet.cidr_block}.  Modification of subnet cidr_block is unsupported!"
    end
    vpc = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource)
    if vpc && subnet.vpc != vpc
      raise "VPC for subnet #{new_resource.name} is #{new_resource.vpc} (#{vpc.id}), but existing subnet (#{subnet.id})'s vpc is #{subnet.vpc.id}.  Modification of subnet VPC is unsupported!"
    end
    if new_resource.availability_zone && subnet.availability_zone_name != new_resource.availability_zone
      raise "availability_zone for subnet #{new_resource.name} is #{new_resource.availability_zone}, but existing subnet (#{subnet.id})'s availability_zone is #{subnet.availability_zone}.  Modification of subnet availability_zone is unsupported!"
    end
  end

  def destroy_aws_object(subnet)
    if purging
      # TODO possibly convert to http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/Client.html#terminate_instances-instance_method
      p = Chef::ChefFS::Parallelizer.new(5)
      p.parallel_do(subnet.instances.to_a) do |instance|
        Cheffish.inline_resource(self, action) do
          aws_instance instance.id do
            action :purge
          end
        end
      end
      p.parallel_do(subnet.network_interfaces.to_a) do |network|
        Cheffish.inline_resource(self, action) do
          aws_network_interface network do
            action :purge
          end
        end
      end
    end
    converge_by "delete #{new_resource.to_s} in VPC #{new_resource.vpc} in #{region}" do
      # If the subnet doesn't exist we can't check state on it - state can only be :pending or :available
      begin
        subnet.delete
      rescue AWS::EC2::Errors::InvalidSubnetID::NotFound
      end
    end
  end

  private

  def update_map_public_ip_on_launch(subnet)
    if !new_resource.map_public_ip_on_launch.nil?
      subnet_desc = subnet.client.describe_subnets(subnet_ids: [ subnet.id ])[:subnet_set].first
      if new_resource.map_public_ip_on_launch
        if !subnet_desc[:map_public_ip_on_launch]
          converge_by "turn on automatic public IPs for subnet #{subnet.id}" do
            subnet.client.modify_subnet_attribute(subnet_id: subnet.id, map_public_ip_on_launch: { value: true })
          end
        end
      else
        if subnet_desc[:map_public_ip_on_launch]
          converge_by "turn off automatic public IPs for subnet #{subnet.id}" do
            subnet.client.modify_subnet_attribute(subnet_id: subnet.id, map_public_ip_on_launch: { value: false })
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

  def update_network_acl(subnet)
    if new_resource.network_acl
      network_acl_id =
        AWSResource.lookup_options({ network_acl: new_resource.network_acl }, resource: new_resource)[:network_acl]
      if subnet.network_acl.id != network_acl_id
        converge_by "update network ACL of subnet #{new_resource.name} to #{new_resource.network_acl}" do
          subnet.network_acl = network_acl_id
        end
      end
    end
  end
end

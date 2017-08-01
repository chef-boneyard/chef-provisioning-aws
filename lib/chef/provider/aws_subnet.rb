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
    options = { vpc_id: new_resource.vpc, cidr_block: cidr_block }
    options[:availability_zone] = new_resource.availability_zone if new_resource.availability_zone
    options = Chef::Provisioning::AWSDriver::AWSResource.lookup_options(options, resource: new_resource)

    converge_by "create subnet #{new_resource.name} with CIDR #{cidr_block} in VPC #{new_resource.vpc} (#{options[:vpc_id]}) in #{region}" do
      subnet = new_resource.driver.ec2_resource.create_subnet(options)
      retry_with_backoff(::Aws::EC2::Errors::InvalidSubnetIDNotFound) do
        new_resource.driver.ec2_resource.create_tags(resources: [subnet.id],tags: [{key: "Name", value: new_resource.name}])
        new_resource.driver.ec2_resource.create_tags(resources: [subnet.id],tags: [{key: "VPC", value: new_resource.vpc}])
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
    if vpc && subnet.vpc.id != vpc.id
      raise "VPC for subnet #{new_resource.name} is #{new_resource.vpc} (#{vpc.id}), but existing subnet (#{subnet.id})'s vpc is #{subnet.vpc.id}.  Modification of subnet VPC is unsupported!"
    end
    if new_resource.availability_zone && subnet.availability_zone != new_resource.availability_zone
      raise "availability_zone for subnet #{new_resource.name} is #{new_resource.availability_zone}, but existing subnet (#{subnet.id})'s availability_zone is #{subnet.availability_zone}.  Modification of subnet availability_zone is unsupported!"
    end
  end

  def destroy_aws_object(subnet)
    if purging
      # TODO possibly convert to http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/Client.html#terminate_instances-instance_method
      p = Chef::ChefFS::Parallelizer.new(5)
      current_driver = self.new_resource.driver
      current_chef_server = self.new_resource.chef_server
      p.parallel_do(subnet.instances.to_a) do |instance|
        Cheffish.inline_resource(self, action) do
          aws_instance instance.id do
            action :purge
            driver current_driver
            chef_server current_chef_server
          end
        end
      end
      p.parallel_do(subnet.network_interfaces.to_a) do |network|
        # It is common during subnet purging for the instance to be terminated but
        # temporarily hanging around - this causes a `The network interface at device index 0 cannot be detached`
        # error to be raised when trying to detach
        retry_with_backoff(::Aws::EC2::Errors::OperationNotPermitted) do
          Cheffish.inline_resource(self, action) do
            aws_network_interface network do
              action :purge
              driver current_driver
              chef_server current_chef_server
            end
          end
        end
      end
    end
    converge_by "delete #{new_resource.to_s} in VPC #{new_resource.vpc} in #{region}" do
      # If the subnet doesn't exist we can't check state on it - state can only be :pending or :available
      begin
        subnet.delete
      rescue ::Aws::EC2::Errors::InvalidSubnetIDNotFound
      end
    end
  end

  private

  def update_map_public_ip_on_launch(subnet)
    if !new_resource.map_public_ip_on_launch.nil?
      subnet_desc = subnet.client.describe_subnets(subnet_ids: [ subnet.id ])[:subnets].first
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
    current_route_table_association = subnet.client.describe_route_tables(filters: [{name: "vpc-id", values: [subnet.vpc.id]}]).route_tables
    route_table_entry = nil
    do_break = false
    # Below snippet gives the entry of route_table who is associated with current subnet either by matching its 
    # subnet_id or with a default subnet (i.e by checking association.main == true & in that case
    # association.subnet_id is nil)
    current_route_table_association.each do |route_tbl|
      if !route_tbl.associations.empty?
        route_tbl.associations.each do |r|
          if r.subnet_id == subnet.id
            route_table_entry = r
            do_break = true
            break
          elsif r.subnet_id.nil? && r.main == true
            route_table_entry = r
          end
        end
        break if do_break
      end
    end
    if new_resource.route_table == :default_to_main
      if !route_table_entry.main
        converge_by "reset route table of subnet #{new_resource.name} to the VPC default" do
          subnet.client.disassociate_route_table(association_id: route_table_entry.route_table_association_id)
        end
      end
    else
      route_table = Chef::Resource::AwsRouteTable.get_aws_object(new_resource.route_table, resource: new_resource)
      if route_table_entry.main && route_table_entry.subnet_id.nil?
        # Even if the user sets the route table explicitly to the main route table,
        # we have work to do here: we need to make the relationship explicit so that
        # it won't be changed when the main route table of the VPC changes.
        converge_by "set route table of subnet #{new_resource.name} to #{new_resource.route_table}" do
          subnet.client.associate_route_table(route_table_id: route_table.id, subnet_id: subnet.id)
        end
      elsif route_table_entry.route_table_id != route_table.id
        # The route table is different now.  Change it.
        converge_by "change route table of subnet #{new_resource.name} to #{new_resource.route_table} (was #{route_table_entry.route_table_id})" do
          subnet.client.disassociate_route_table(association_id: route_table_entry.route_table_association_id) if route_table_entry.main == false
          subnet.client.associate_route_table(route_table_id: route_table.id, subnet_id: subnet.id)
        end
      end
    end
  end

  def update_network_acl(subnet)
    if new_resource.network_acl
      network_acl_id =
        AWSResource.lookup_options({ network_acl: new_resource.network_acl }, resource: new_resource)[:network_acl]
      # Below snippet gives the entry of network_acl who is associated with current subnet by matching its subnet_id
      network_acl_association = subnet.client.describe_network_acls(filters: [{name: "vpc-id", values: [subnet.vpc.id]}, {name: "association.subnet-id", values: [subnet.id]}]).network_acls.first.associations
      current_network_acl_association = network_acl_association.find { |r| r.subnet_id == subnet.id } unless network_acl_association.empty?

      if current_network_acl_association.network_acl_id != network_acl_id && !current_network_acl_association.nil?
        converge_by "update network ACL of subnet #{new_resource.name} to #{new_resource.network_acl}" do
          subnet.client.replace_network_acl_association(association_id: current_network_acl_association.network_acl_association_id, network_acl_id: network_acl_id)
        end
      end
    end
  end
end

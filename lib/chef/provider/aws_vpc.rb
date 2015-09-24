require 'chef/provisioning/aws_driver/aws_provider'
require 'date'
require 'chef/provisioning'
require 'retryable'

class Chef::Provider::AwsVpc < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::EC2ConvergeTags

  provides :aws_vpc

  class NeverObtainedExistence < RuntimeError; end

  def action_create
    vpc = super

    # Update DNS attributes
    update_vpc_attributes(vpc)

    #
    # Attach/detach internet gateway
    #
    if !new_resource.internet_gateway.nil?
      update_internet_gateway(vpc)
    end

    # Replace the main route table for the VPC
    if !new_resource.main_route_table.nil?
      update_main_route_table(vpc)
    end

    # Update the main route table
    if !new_resource.main_routes.nil?
      update_main_routes(vpc, new_resource.main_route_table)
    end

    # Update DHCP options
    if !new_resource.dhcp_options.nil?
      update_dhcp_options(vpc)
    end
  end

  protected

  def create_aws_object
    options = { }
    options[:instance_tenancy] = new_resource.instance_tenancy if new_resource.instance_tenancy

    converge_by "create VPC #{new_resource.name} in #{region}" do
      vpc = new_resource.driver.ec2.vpcs.create(new_resource.cidr_block, options)
      wait_for_state(vpc, [:available])
      retry_with_backoff(AWS::EC2::Errors::InvalidVpcID::NotFound) do
        vpc.tags['Name'] = new_resource.name
      end
      vpc
    end
  end

  def update_aws_object(vpc)
    if new_resource.instance_tenancy && new_resource.instance_tenancy != vpc.instance_tenancy
      raise "Tenancy of VPC #{new_resource.name} is #{vpc.instance_tenancy}, but desired tenancy is #{new_resource.instance_tenancy}.  Instance tenancy of VPCs cannot be changed!"
    end
    if new_resource.cidr_block && new_resource.cidr_block != vpc.cidr_block
      raise "CIDR block of VPC #{new_resource.name} is #{vpc.cidr_block}, but desired CIDR block is #{new_resource.cidr_block}.  VPC CIDR blocks cannot currently be changed!"
    end
  end

  def destroy_aws_object(vpc)
    if purging
      vpc.subnets.each do |s|
        Cheffish.inline_resource(self, action) do
          aws_subnet s do
            action :purge
          end
        end
      end
      # If any of the below resources start needing complicated delete logic (dependent resources needing to
      # be deleted) move that logic into `delete_aws_resource` and add the purging logic to the resource
      vpc.network_acls.each       { |o| o.delete unless o.default? }
      vpc.network_interfaces.each do |ni|
        Cheffish.inline_resource(self, action) do
          aws_network_interface ni do
            action :purge
          end
        end
      end

      vpc.security_groups.each do |sg|
        unless sg.name == 'default'
          Cheffish.inline_resource(self, action) do
            aws_security_group sg do
              action :purge
            end
          end
        end
      end

      #SDK V2
      vpc_new_sdk = new_resource.driver.ec2_resource.vpc(vpc.id)
      vpc_new_sdk.route_tables.each do |rt|
        unless rt.associations.any? { |association| association.main }
          Cheffish.inline_resource(self, action) do
            aws_route_table rt do
              action :purge
            end
          end
        end
      end

      vpc_peering_connections = []
      %w(
        requester-vpc-info.vpc-id
        accepter-vpc-info.vpc-id
      ).each do |filter|
        vpc_peering_connections += new_resource.driver.ec2_client.describe_vpc_peering_connections({
            :filters => [
                {
                    :name => filter,
                    :values => [vpc.id]
                }
            ]
        }).vpc_peering_connections
      end

      vpc_peering_connections.each do |pc_type|
        pc_resource = new_resource.driver.ec2_resource.vpc_peering_connection(pc_type.vpc_peering_connection_id)
        Cheffish.inline_resource(self, action) do
          aws_vpc_peering_connection pc_resource do
            action :purge
          end
        end
      end
    end

    # Detach or destroy the internet gateway
    ig = vpc.internet_gateway
    if ig
      Cheffish.inline_resource(self, action) do
        aws_internet_gateway ig do
          if ig.tags['OwnedByVPC'] == vpc.id
            action :destroy
          else
            action :detach
          end
        end
      end
    end

    # We cannot delete the main route table, and it will be deleted when the VPC is deleted anyways

    converge_by "delete #{new_resource.to_s} in #{region}" do
      vpc.delete
    end
  end

  private

  def update_vpc_attributes(vpc)
    # Figure out what (if anything) we need to update
    update_attributes = {}
    %w(enable_dns_support enable_dns_hostnames).each do |name|
      desired_value = new_resource.public_send(name)
      if !desired_value.nil?
        # enable_dns_support -> enableDnsSupport
        aws_attr_name = name.gsub(/_./) { |v| v[1..1].upcase }
        name = name.to_sym
        actual_value = vpc.client.describe_vpc_attribute(vpc_id: vpc.id, attribute: aws_attr_name)
        if actual_value[name][:value] != desired_value
          update_attributes[name] = { old_value: actual_value[name][:value], value: desired_value }
        end
      end
    end

    update_attributes.each do |name, update|
      converge_by "update #{name} to #{update[:value].inspect} (was #{update[:old_value].inspect}) in VPC #{new_resource.name} (#{vpc.id})" do
        vpc.client.modify_vpc_attribute(:vpc_id => vpc.id, name => { value: update[:value] })
      end
    end
  end

  def update_internet_gateway(vpc)
    current_ig = vpc.internet_gateway
    case new_resource.internet_gateway
      when String, Chef::Resource::AwsInternetGateway, AWS::EC2::InternetGateway
        new_ig = Chef::Resource::AwsInternetGateway.get_aws_object(new_resource.internet_gateway, resource: new_resource)
        if !current_ig
          Cheffish.inline_resource(self, action) do
            aws_internet_gateway new_ig do
              vpc vpc.id
            end
          end
        elsif current_ig != new_ig
          Cheffish.inline_resource(self, action) do
            aws_internet_gateway current_ig do
              if current_ig.tags['OwnedByVPC'] == vpc.id
                action :destroy
              else
                action :detach
              end
            end
            aws_internet_gateway new_ig do
              vpc vpc.id
            end
          end
        end
      when true
        if !current_ig
          Cheffish.inline_resource(self, action) do
            aws_internet_gateway "igw-managed-by-#{vpc.id}" do
              vpc vpc.id
              aws_tags 'OwnedByVPC' => vpc.id
            end
          end
        end
      when false
        if current_ig
          Cheffish.inline_resource(self, action) do
            aws_internet_gateway current_ig.id do
              if current_ig.tags['OwnedByVPC'] == vpc.id
                action :destroy
              else
                action :detach
              end
            end
          end
        end
    end
  end

  def update_main_route_table(vpc)
    desired_route_table = Chef::Resource::AwsRouteTable.get_aws_object(new_resource.main_route_table, resource: new_resource)
    current_route_table = vpc.route_tables.main_route_table
    if current_route_table.id != desired_route_table.id
      main_association = current_route_table.associations.select { |a| a.main? }.first
      if !main_association
        raise "No main route table association found for #{new_resource.to_s} current main route table #{current_route_table.id}: error!  Probably a race condition."
      end
      converge_by "change main route table for #{new_resource.to_s} to #{desired_route_table.id} (was #{current_route_table.id})" do
        vpc.client.replace_route_table_association(
          association_id: main_association.id,
          route_table_id: desired_route_table.id
        )
      end
    end
    desired_route_table
  end

  def update_main_routes(vpc, main_route_table)
    # If no route table is provided and we fetch the current main one from AWS,
    # there is no guarantee that is the 'default' route table created when
    # creating the VPC
    main_route_table ||= vpc.route_tables.main_route_table
    main_routes = new_resource.main_routes
    Cheffish.inline_resource(self, action) do
      aws_route_table main_route_table.id do
        vpc vpc
        routes main_routes
      end
    end
    main_route_table
  end

  def update_dhcp_options(vpc)
    dhcp_options = vpc.dhcp_options
    desired_dhcp_options = Chef::Resource::AwsDhcpOptions.get_aws_object(new_resource.dhcp_options, resource: new_resource)
    if dhcp_options != desired_dhcp_options
      converge_by "change DHCP options for #{new_resource.to_s} to #{new_resource.dhcp_options} (#{desired_dhcp_options.id}) - was #{dhcp_options.id}" do
        vpc.dhcp_options = desired_dhcp_options
      end
    end
  end
end

require 'chef/provisioning/aws_driver/aws_provider'
require 'date'

class Chef::Provider::AwsVpc < Chef::Provisioning::AWSDriver::AWSProvider

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
      main_route_table = update_main_route_table(vpc)
    end

    # Update the main route table
    if !new_resource.main_routes.nil?
      update_main_routes(vpc, main_route_table)
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

    converge_by "create new VPC #{new_resource.name} in #{region}" do
      vpc = new_resource.driver.ec2.vpcs.create(new_resource.cidr_block, options)
      vpc.tags['Name'] = new_resource.name
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
      # TODO we need to destroy the associated data bags as well.
      vpc.instances.each          { |o| o.delete }
      vpc.instances.each          { |o| sleep 0.5 while o.status != :terminated }
      vpc.network_acls.each       { |o| o.delete unless o.default? }
      vpc.network_interfaces.each { |o| o.delete }
      vpc.subnets.each            { |o| o.delete }
      vpc.route_tables.each       { |o| o.delete unless o.main? }
      vpc.security_groups.each    { |o| o.delete unless o.name == 'default' }
    end

    # Detach or destroy the internet gateway
    ig = vpc.internet_gateway
    if ig
      converge_by "detach Internet Gateway #{ig.id} in #{region} from VPC #{new_resource.name} (#{vpc.id}" do
        ig.detach(vpc.id)
      end
      if ig.tags['OwnedByVPC'] == vpc.id
        converge_by "destroy Internet Gateway #{ig.id} in #{region} (owned by VPC #{new_resource.name} (#{vpc.id}))" do
          ig.delete
        end
      end
    end

    # TODO delete main route table & routes if they exist and we created them

    converge_by "delete VPC #{new_resource.name} (#{vpc.id}) in #{region}" do
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
        converge_by "attach Internet Gateway #{new_resource.internet_gateway} to VPC #{vpc.id}" do
          new_ig.attach(vpc.id)
        end
      elsif current_ig != new_ig
        converge_by "replace Internet Gateway #{current_ig.id} on VPC #{vpc.id} with new Internet Gateway #{new_ig.id}" do
          current_ig.detach(vpc.id)
          new_ig.attach(vpc.id)
        end
        if current_ig.tags['OwnedByVPC'] == vpc.id
          converge_by "destroy Internet Gateway #{current_ig.id} in #{region} (owned by VPC #{vpc.id})" do
            current_ig.delete
          end
        end
      end
    when true
      if !current_ig
        converge_by "attach new Internet Gateway to VPC #{vpc.id}" do
          current_ig = AWS.ec2(config: vpc.config).internet_gateways.create
          action_handler.report_progress "create Internet Gateway #{current_ig.id}"
          current_ig.tags['OwnedByVPC'] = vpc.id
          action_handler.report_progress "tag Internet Gateway #{current_ig.id} as OwnedByVpc: #{vpc.id}"
          vpc.internet_gateway = current_ig
        end
      end
    when false
      if current_ig
        converge_by "detach Internet Gateway #{current_ig.id} from VPC #{vpc.id}" do
          current_ig.detach(vpc.id)
        end
        if current_ig.tags['OwnedByVPC'] == vpc.id
          converge_by "destroy Internet Gateway #{current_ig.id} in #{region} (owned by VPC #{vpc.id})" do
            current_ig.delete
          end
        end
      end
    end
  end

  def update_main_route_table(vpc)
    desired_route_table = Chef::Resource::AwsRouteTable.get_aws_object(new_resource.main_route_table, resource: new_resource)
    current_route_table = vpc.route_tables.main_route_table
    if current_route_table != desired_route_table
      main_association = current_route_table.associations.select { |a| a.main? }.first
      if !main_association
        raise "No main route table association found for VPC #{new_resource.name} (#{vpc.id})'s current main route table #{current_route_table.id}: error!  Probably a race condition."
      end
      converge_by "change main route table for VPC #{new_resource.name} (#{vpc.id}) to #{desired_route_table.id} (was #{current_route_table.id})" do
        vpc.client.replace_route_table_association(
          association_id: main_association.id,
          route_table_id: desired_route_table.id)
      end
    end
    desired_route_table
  end

  def update_main_routes(vpc, main_route_table)
    main_route_table ||= vpc.route_tables.main_route_table
    aws_route_table main_route_table do
      vpc vpc
      routes new_resource.main_routes
    end
    main_route_table
  end

  def update_dhcp_options(vpc)
    dhcp_options = vpc.dhcp_options
    desired_dhcp_options = Chef::Resource::AwsDhcpOptions.get_aws_object(new_resource.dhcp_options, resource: new_resource)
    if dhcp_options != desired_dhcp_options
      converge_by "change DHCP options for VPC #{new_resource.name} (#{vpc.id}) to #{new_resource.dhcp_options} (#{desired_dhcp_options.id}) - was #{dhcp_options.id}" do
        vpc.dhcp_options = desired_dhcp_options
      end
    end
  end
end

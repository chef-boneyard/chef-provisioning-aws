require 'chef/provisioning/aws_driver/aws_provider'
require 'date'

class Chef::Provider::AwsVpc < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    vpc = new_resource.aws_object
    if vpc
      update_vpc(vpc)
    else
      vpc = create_vpc
    end

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

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      ig = aws_object.internet_gateway
      if ig
        converge_by "detach Internet Gateway #{ig.id} in #{region}" do
          ig.detach(vpc.id)
        end
        if ig.tags['OwnedByVPC'] == aws_object.id
          converge_by "destroy Internet Gateway #{ig.id} in #{region} (owned by VPC #{new_resource.name} (#{aws_object.id}))" do
            ig.delete
          end
        end
      end
      converge_by "delete VPC #{aws_object.id} in #{region}" do
        aws_object.delete
      end
    end

    new_resource.delete_managed_entry(action_handler)
  end

  private

  def create_vpc
    vpc = nil
    converge_by "create new VPC #{new_resource.name} in #{region}" do
      opts = { }
      opts[:instance_tenancy] = new_resource.instance_tenancy if new_resource.instance_tenancy
      vpc = driver.ec2.vpcs.create(new_resource.cidr_block, opts)
      vpc.tags['Name'] = new_resource.name
    end
    new_resource.save_managed_entry(vpc, action_handler)
    vpc
  end

  def update_vpc(vpc)
    if new_resource.instance_tenancy && new_resource.instance_tenancy != vpc.instance_tenancy
      raise "Tenancy of VPC #{new_resource.vpc} is #{vpc.instance_tenancy}, but desired tenancy is #{new_resource.instance_tenancy}.  Instance tenancy of VPCs cannot be changed!"
    end
    if new_resource.cidr_block && new_resource.cidr_block != vpc.cidr_block
      raise "CIDR block of VPC #{new_resource.vpc} is #{vpc.cidr_block}, but desired CIDR block is #{new_resource.cidr_block}.  VPC CIDR blocks cannot currently be changed!"
    end
  end

  def update_vpc_attributes(vpc)
    # Figure out what (if anything) we need to update
    update_attributes = {}
    %w(enable_dns_support enable_dns_hostnames).each do |name|
      desired_value = new_resource.public_send(name)
      if !desired_value.nil?
        # enable_dns_support -> enableDnsSupport
        aws_attr_name = name.gsub(/_./) { |v| v[1..1].upcase }
        name = name.to_sym
        actual_value = driver.ec2.client.describe_vpc_attribute(vpc_id: vpc.id, attribute: aws_attr_name)
        if actual_value[name][:value] != desired_value
          update_attributes[name] = { old_value: actual_value[name][:value], value: desired_value }
        end
      end
    end

    update_attributes.each do |name, update|
      converge_by "update #{name} to #{update[:value].inspect} (was #{update[:old_value].inspect}) in VPC #{new_resource.name} (#{vpc.id})" do
        driver.ec2.client.modify_vpc_attribute(:vpc_id => vpc.id, name => { value: update[:value] })
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
          current_ig = driver.ec2.internet_gateways.create
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
    main_route_table = Chef::Resource::AwsRouteTable.get_aws_object(new_resource.main_route_table, resource: new_resource)
    current_route_table = vpc.route_tables.main_route_table
    if route_table != main_route_table
      main_association = current_route_table.associations.select { |a| a.main? }.first
      if !main_association
        raise "No main route table association found for VPC #{vpc.id}'s current main route table #{main_route_table.id}: error!  Probably a race condition."
      end
      converge_by "change main route table for VPC #{vpc.id} to #{route_table.id} (was #{main_route_table.id})" do
        aws_driver.ec2.client.replace_route_table_association(
          association_id: main_association.id,
          route_table_id: main_route_table.id)
      end
    end
    main_route_table
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

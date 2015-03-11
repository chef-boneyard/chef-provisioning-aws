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
  end

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      ig = aws_object.internet_gateway
      if ig
        converge_by "detach Internet Gateway #{ig.id} in #{region}" do
          aws_object.internet_gateway = nil
        end
        converge_by "destroy Internet Gateway #{ig.id} in #{region}" do
          ig.delete
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

  def update_internet_gateway(vpc)
    case new_resource.internet_gateway
    when String
      internet_gateway = get_aws_object(:internet_gateway, new_resource.internet_gateway)
      if !vpc.internet_gateway
        converge_by "attach Internet Gateway #{new_resource.internet_gateway} to VPC #{vpc.id}" do
          vpc.internet_gateway = internet_gateway
        end
      elsif vpc.internet_gateway != internet_gateway
        converge_by "replace Internet Gateway #{vpc.internet_gateway.id} on VPC #{vpc.id} with new Internet Gateway #{internet_gateway}" do
          vpc.internet_gateway = internet_gateway
        end
      end
    when true
      if !vpc.internet_gateway
        converge_by "attach new Internet Gateway to VPC #{vpc.id}" do
          internet_gateway = driver.ec2.internet_gateways.create
          action_handler.report_progress "create Internet Gateway #{internet_gateway.id}"
          vpc.internet_gateway = internet_gateway
        end
      end
    when false
      if vpc.internet_gateway
        converge_by "delete Internet Gateway #{vpc.internet_gateway.id} attached to VPC #{vpc.id}" do
          vpc.internet_gateway.delete
        end
      end
    when :detach
      if vpc.internet_gateway
        converge_by "detach Internet Gateway #{vpc.internet_gateway.id} from VPC #{vpc.id}" do
          vpc.internet_gateway = nil
        end
      end
    end
  end

  def update_main_route_table(vpc)
    main_route_table = get_aws_object(:route_table, new_resource.main_route_table)
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
end

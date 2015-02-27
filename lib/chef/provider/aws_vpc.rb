require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsVpc < Chef::Provider::AwsProvider

  action :create do
    fail "Can't create a VPC without a CIDR block" if new_resource.cidr_block.nil?

    if existing_vpc
      vpc = existing_vpc
    else
      converge_by "create new VPC #{fqn} in #{new_driver.aws_config.region}" do
        opts = { :instance_tenancy => :default}
        vpc = new_driver.ec2.vpcs.create(new_resource.cidr_block, opts)
        vpc.tags['Name'] = new_resource.name
        new_resource.vpc_id vpc.id
        new_resource.save
      end
    end

    #
    # Attach/detach internet gateway
    #
    case new_resource.internet_gateway
    when String
      if !vpc.internet_gateway
        converge_by "attach #{new_resource.internet_gateway} Internet Gateway to VPC #{vpc.id}" do
          vpc.internet_gateway = new_driver.ec2.internet_gateways[new_resource.internet_gateway]
        end
      elsif vpc.internet_gateway.id != new_resource.internet_gateway
        converge_by "replace Internet Gateway #{vpc.internet_gateway.id} on VPC #{vpc.id} with new Internet Gateway #{new_resource.internet_gateway}" do
          vpc.internet_gateway = new_driver.ec2.internet_gateways[new_resource.internet_gateway]
        end
      end
    when true
      if !vpc.internet_gateway
        converge_by "attach new Internet Gateway to VPC #{vpc.id}" do
          vpc.internet_gateway = new_driver.ec2.internet_gateways.create
          action_handler.report_progress "create Internet Gateway #{vpc.internet_gateway.id}"
        end
      end
    else
      if vpc.internet_gateway == false
        converge_by "delete Internet Gateway #{vpc.internet_gateway.id} attached to VPC #{vpc.id}" do
          vpc.internet_gateway.delete
        end
      end
    end

    # Attach (or detach) the internet gateway route
    internet_gateway_routes = vpc.route_tables.main_route_table.routes.
      select { |r| r.internet_gateway && r.internet_gateway.id != 'local' }.
      inject({}) { |h,r| h[r.destination_cidr_block] = r; h }
    (new_resource.internet_gateway_routes || []).each do |new_route|
      if !internet_gateway_routes.delete(new_route)
        # It's not there, create it
        converge_by "create Internet Gateway route #{new_route} on VPC #{vpc.id}" do
          vpc.route_tables.main_route_table.create_route(new_route, internet_gateway: vpc.internet_gateway.id)
        end
      end
    end
    # Any remaining internet gateway routes, we don't want anymore.  Remove.
    internet_gateway_routes.each_value do |route|
      converge_by "delete Internet Gateway route #{route.destination_cidr_block} on VPC #{vpc.id}" do
        route.delete
      end
    end
  end

  action :delete do
    if existing_vpc
      converge_by "delete VPC #{fqn} in #{new_driver.aws_config.region}" do
        existing_vpc.delete
      end
    end

    new_resource.delete
  end

  def existing_vpc
    @existing_vpc ||= begin
      new_driver.ec2.vpcs.with_tag('Name', new_resource.name).first
    rescue
      nil
    end
  end

  def id
    new_resource.vpc_id
  end

end

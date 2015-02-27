require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsRouteTable < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    route_table = new_resource.aws_object
    vpc = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource)
    if route_table
      vpc = update_route_table(vpc, route_table)
    else
      vpc, route_table = create_route_table(vpc)
    end

    if !new_resource.routes.nil?
      update_routes(vpc, route_table)
    end
  end

  action :delete do
    route_table = new_resource.aws_object
    if route_table
      converge_by "delete route table #{new_resource.name} (#{route_table.id}) in #{region}" do
        route_table.delete
      end
    end

    new_resource.delete_managed_entry(action_handler)
  end

  private

  def create_route_table(vpc)
    route_table = nil
    converge_by "create new route table #{new_resource.name} in VPC #{new_resource.vpc} and region #{region}" do
      options = {}
      options[:vpc] = vpc if vpc
      options = AWSResource.lookup_options(options, resource: new_resource)
      route_table = driver.ec2.route_tables.create(options)
      route_table.tags['Name'] = new_resource.name
      new_resource.save_managed_entry(route_table, action_handler)
    end
    [ vpc, route_table ]
  end

  def update_route_table(vpc, route_table)
    if vpc && route_table.vpc != vpc
      raise "VPC of route table #{new_resource.name} (#{route_table.id}) is #{route_table.vpc.id}, but desired vpc is #{new_resource.vpc}!  Moving (or rather, recreating) a route table is not yet supported."
    end
    vpc || route_table.vpc
  end

  def update_routes(vpc, route_table)
    # Collect current routes
    current_routes = {}
    route_table.routes.each do |route|
      # Ignore the automatic local route
      next if route.target.id == 'local'
      current_routes[route.destination_cidr_block] = route
    end

    # Add or replace routes from `routes`
    new_resource.routes.each do |destination_cidr_block, route_target|
      options = get_route_target(vpc, route_target)
      target = options.values.first
      # If we already have a route to that CIDR block, replace it.
      if current_routes[destination_cidr_block]
        current_route = current_routes.delete(destination_cidr_block)
        if current_route.target != target
          action_handler.perform_action "reroute #{destination_cidr_block} to #{route_target} (#{target.id}) instead of #{current_route.target.id}" do
            current_route.replace(options)
          end
        end
      else
        action_handler.perform_action "route #{destination_cidr_block} to #{route_target} (#{target.id})" do
          route_table.create_route(destination_cidr_block, options)
        end
      end
    end

    # Delete anything that's left (that wasn't replaced)
    current_routes.values.each do |current_route|
      action_handler.perform_action "remove route sending #{current_route.destination_cidr_block} to #{current_route.target.id}" do
        current_route.delete
      end
    end
  end

  def get_route_target(vpc, route_target)
    case route_target
    when :internet_gateway
      route_target = { internet_gateway: vpc.internet_gateway }
      if !route_target[:internet_gateway]
        raise "VPC #{new_resource.vpc} (#{vpc.id}) does not have an internet gateway to route to!  Use `internet_gateway true` on the VPC itself to create one."
      end
    when /^igw-[A-Fa-f0-9]{8}$/, Chef::Resource::AwsInternetGateway, AWS::EC2::InternetGateway
      route_target = { internet_gateway: route_target }
    when /^eni-[A-Fa-f0-9]{8}$/, Chef::Resource::AwsNetworkInterface, AWS::EC2::NetworkInterface
      route_target = { network_interface: route_target }
    when String, Chef::Resource::Machine, AWS::EC2::Instance
      route_target = { instance: route_target }
    when Hash
      if route_target.size != 1
        raise "Route target #{route_target} must have exactly one key, either :internet_gateway, :instance or :network_interface!"
      end
      route_target = route_target.dup
    else
      raise "Unrecognized route destination #{route_target.inspect}"
    end
    route_target.each do |name, value|
      case name
      when :instance
        route_target[name] = Chef::Resource::AwsInstance.get_aws_object(value, resource: new_resource)
      when :network_interface
        route_target[name] = Chef::Resource::AwsNetworkInterface.get_aws_object(value, resource: new_resource)
      when :internet_gateway
        route_target[name] = Chef::Resource::AwsInternetGateway.get_aws_object(value, resource: new_resource)
      end
    end
    route_target
  end
end

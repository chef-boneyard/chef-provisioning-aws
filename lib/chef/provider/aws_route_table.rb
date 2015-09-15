require 'chef/provisioning/aws_driver/aws_provider'
require 'retryable'

class Chef::Provider::AwsRouteTable < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::EC2ConvergeTags

  provides :aws_route_table

  def action_create
    route_table = super

    if !new_resource.routes.nil?
      update_routes(vpc, route_table, new_resource.ignore_route_targets)
    end

    update_virtual_private_gateways(route_table, new_resource.virtual_private_gateways)
  end

  protected

  def create_aws_object
    options = {}
    options[:vpc] = new_resource.vpc
    options = AWSResource.lookup_options(options, resource: new_resource)
    self.vpc = Chef::Resource::AwsVpc.get_aws_object(options[:vpc], resource: new_resource)

    converge_by "create route table #{new_resource.name} in VPC #{new_resource.vpc} (#{vpc.id}) and region #{region}" do
      route_table = new_resource.driver.ec2.route_tables.create(options)
      retry_with_backoff(AWS::EC2::Errors::InvalidRouteTableID::NotFound) do
        route_table.tags['Name'] = new_resource.name
      end
      route_table
    end
  end

  def update_aws_object(route_table)
    self.vpc = route_table.vpc

    if new_resource.vpc
      desired_vpc = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource)
      if vpc != desired_vpc
        raise "VPC of route table #{new_resource.to_s} is #{route_table.vpc.id}, but desired VPC is #{new_resource.vpc}!  The AWS SDK does not support updating the main route table except by creating a new route table."
      end
    end
  end

  def destroy_aws_object(route_table)
    converge_by "delete #{new_resource.to_s} in #{region}" do
      begin
        route_table.delete
      rescue AWS::EC2::Errors::DependencyViolation
        raise "#{new_resource.to_s} could not be deleted because it is the main route table for #{route_table.vpc.id} or it is being used by a subnet"
      end
    end
  end

  private

  attr_accessor :vpc

  def update_routes(vpc, route_table, ignore_route_targets = [])
    # Collect current routes
    current_routes = {}
    route_table.routes.each do |route|
      # Ignore the automatic local route
      next if route.target.id == 'local'
      next if ignore_route_targets.find { |target| route.target.id.match(/#{target}/) }
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

  def update_virtual_private_gateways(route_table, gateway_ids)
    current_propagating_vgw_set = route_table.client.describe_route_tables(route_table_ids: [route_table.id]).route_table_set.first.propagating_vgw_set

    # Add propagated routes
    if gateway_ids
      gateway_ids.each do |gateway_id|
        if !current_propagating_vgw_set.reject! { |vgw_set| vgw_set[:gateway_id] == gateway_id }
          action_handler.perform_action "enable route propagation for route table #{route_table.id} to virtual private gateway #{gateway_id}" do
            route_table.client.enable_vgw_route_propagation(route_table_id: route_table.id, gateway_id: gateway_id)
          end
        end
      end
    end

    # Delete anything that's left
    if current_propagating_vgw_set
      current_propagating_vgw_set.each do |vgw_set|
        action_handler.perform_action "disabling route propagation for route table #{route_table.id} from virtual private gateway #{vgw_set[:gateway_id]}" do
          route_table.client.disable_vgw_route_propagation(route_table_id: route_table.id, gateway_id: vgw_set[:gateway_id])
        end
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
    when String, Chef::Resource::AwsInstance
      route_target = { instance: route_target }
    when Chef::Resource::Machine
      route_target = { instance: route_target.name }
    when AWS::EC2::Instance, Aws::EC2::Instance
      route_target = { instance: route_target.id }
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

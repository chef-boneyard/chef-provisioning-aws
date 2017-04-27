require 'chef/provisioning/aws_driver/aws_resource_with_entry'

#
# An AWS route table, specifying where to route traffic destined for particular
# sets of IPs.
#
# `name` is not guaranteed unique for an AWS account; therefore, Chef will
# store the route table ID associated with this name in your Chef server in the
# data bag `data/aws_route_Table/<name>`.
#
# API documentation for the AWS Ruby SDK for VPCs (and the object returned from `aws_object` can be found here:
#
# - http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/RouteTable.html
#
class Chef::Resource::AwsRouteTable < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  include Chef::Provisioning::AWSDriver::AWSTaggable
  aws_sdk_type ::Aws::EC2::RouteTable

  require 'chef/resource/aws_vpc'

  #
  # The name of this route table.
  #
  attribute :name,   kind_of: String, name_attribute: true

  #
  # The VPC of this route table.
  #
  # May be one of:
  # - The name of an `aws_vpc` Chef resource.
  # - An actual `aws_vpc` resource.
  # - An AWS `VPC` object.
  #
  # This is required for new route tables.
  #
  attribute :vpc,    kind_of: [ String, AwsVpc, ::Aws::EC2::Vpc ], required: true

  #
  # Enable route propagation from one or more virtual private gateways
  #
  # The value should be an array of virtual private gateway ID:
  # ```ruby
  # virtual_private_gateways ['vgw-abcd1234', 'vgw-abcd5678']
  # ```
  #
  attribute :virtual_private_gateways, kind_of: [ String, Array ],
            coerce: proc { |v| [v].flatten }

  #
  # The routes for this route table.
  #
  # If specified, this must be a complete specification of all routes: it will
  # add any new routes and remove any old ones.
  #
  # This is in the form of a Hash, like so:
  #
  # ```ruby
  # main_routes '10.0.0.0/8' => 'internal_vpn',
  #             '0.0.0.0/0' => :internet_gateway
  # ```
  #
  # The destination (the left side of the `=>`) is always a CIDR block.
  # The target (the right side of the `=>`) can be one of several things:
  # - { internet_gateway: <AWS Internet Gateway ID or object> }
  # - { nat_gateway: <AWS Nat Gateway ID or object> }
  # - { instance: <Chef machine name or resource, AWS Instance ID or object> }
  # - { network_interface: <AWS Network Interface ID or object> }
  # - { vpc_peering_connection: <AWS VPC Peering Connection ID or object> }
  # - <AWS Internet Gateway, Instance, Network Interface or a VPC Peering Connection <ID or object)>
  # - Chef machine name
  # - Chef machine resource
  #
  attribute :routes, kind_of: Hash

  #
  # Regex to ignore one or more route targets.
  #
  # This is helpful when configuring HA NAT instances. If a NAT instance fails
  # a auto-scaling group may launch a new NAT instance and update the route
  # table accordingly. Chef provisioning should not attempt to change or remove
  # this route.
  #
  # This attribute is specified as a regex since the full ID of the
  # instance/network interface is not known ahead of time. In most cases the
  # NAT instance route will point at a network interface attached to the NAT
  # instance. The ID prefix for network interfaces is 'eni'. The following
  # example shows how to ignore network interface routes.
  #
  # ```ruby
  # ignore_route_targets ['^eni-']
  # ```
  attribute :ignore_route_targets, kind_of: [ String, Array ], default: [],
            coerce: proc { |v| [v].flatten }

  attribute :route_table_id, kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^rtb-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2_resource.route_table(id) if id
    begin
      # try accessing it to find out if it exists
      result.vpc_id if result
    rescue ::Aws::EC2::Errors::InvalidRouteTableIDNotFound
      result = nil
    end
    result
  end
end

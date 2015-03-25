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
  aws_sdk_type AWS::EC2::RouteTable

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
  attribute :vpc,    kind_of: [ String, AwsVpc, AWS::EC2::VPC ], required: true

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
  # - { instance: <Chef machine name or resource, AWS Instance ID or object> }
  # - { network_interface: <AWS Network Interface ID or object> }
  # - <AWS Internet Gateway, Instance or Network Interface <ID or object)>
  # - Chef machine name
  # - Chef machine resource
  #
  attribute :routes, kind_of: Hash

  attribute :route_table_id, kind_of: String, aws_id_attribute: true, lazy_default: proc {
    name =~ /^rtb-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2.route_tables[id] if id
    begin
      # try accessing it to find out if it exists
      result.vpc if result
    rescue AWS::EC2::Errors::InvalidRouteTableID::NotFound
      result = nil
    end
    result
  end
end

require 'chef/provisioning/aws_driver/aws_resource_with_entry'

#
# Represents an AWS VPC.
#
# This allows you to finely control network access and security for your
# instances, creating a "walled garden" which cannot be accessed by the Internet
# (or get out to it) without explicitly enabling it through subnets, route tables,
# internet gateways and NATs.
#
# VPCs and network security are closely related with the following other resources:
# - `aws_subnet`: sub-sections of a VPC that can be walled off from each other, which actually contain instances
# - `aws_security_group`: descriptions of instances--particularly, who can talk to them and who they can talk to.
# - `aws_route_table`: descriptions of where traffic should be routed when an instance in a subnet tries to talk to a particular IP.
#
# `name` is not guaranteed unique for an AWS account; therefore, Chef will
# store the VPC ID associated with this name in your Chef server in the
# data bag `data/aws_vpc/<name>`.
#
# General documentation on AWS VPCs can be found here:
#
# - http://aws.amazon.com/documentation/vpc/
#
# API documentation for the AWS Ruby SDK for VPCs (and the object returned from `aws_object` can be found here:
#
# - http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/VPC.html
#
class Chef::Resource::AwsVpc < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::EC2::VPC

  require 'chef/resource/aws_route_table'

  actions :create, :delete, :nothing
  default_action :create

  #
  # The name of this VPC.
  #
  attribute :name, kind_of: String, name_attribute: true

  #
  # The CIDR block of IP addresses allocated to this VPC.
  #
  # For example:
  # - `'10.0.0.0/24'` gives you 256 addresses.
  # - `'10.0.0.0/16'` gives you 65536 addresses.
  #
  # This must be specified: there is no default, and it cannot be changed.
  #
  attribute :cidr_block, kind_of: String

  #
  # The instance tenancy of this VPC.
  #
  # - `:default` allows any tenancy
  # - `:dedicated` forces all instances to be dedicated
  #
  # Defaults, not surprisingly, to `default`.
  #
  attribute :instance_tenancy, equal_to: [ :default, :dedicated ]

  #
  # Whether this VPC should have an Internet Gateway or not.
  #
  # - `true` will create an Internet Gateway and attach it to the VPC, if one is not attached currently.
  # - `false` will delete the Internet Gateway attached to the VPC, if any.
  # - `:detach` will detach the Internet Gateway from the VPC, if there is one.
  # - You may specify the AWS ID of an actual Internet Gateway
  #
  attribute :internet_gateway#, kind_of: [ String, AWS::EC2::InternetGateway ], equal_to: [ true, false, :detach ]

  #
  # The main route table.
  #
  # May be one of:
  # - The name of an `aws_route_table` Chef resource.
  # - An actual `aws_route_table` resource.
  # - An AWS `route_table` object.
  #
  attribute :main_route_table, kind_of: [ String, AwsRouteTable, AWS::EC2::RouteTable ]

  #
  # The routes for the main route table.
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
  attribute :main_routes, kind_of: Hash

  attribute :vpc_id, kind_of: String, aws_id_attribute: true, lazy_default: proc {
    name =~ /^vpc-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2.vpcs[id] if id
    result && result.exists? ? result : nil
  end
end

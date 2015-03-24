require 'chef/provisioning/aws_driver/aws_resource_with_entry'

#
# An AWS subnet is a sub-section of a VPC, walled gardens within the walled garden;
# they share a space of IP addresses with other subnets in the VPC but can otherwise
# be walled off from each other.
#
# `name` is not guaranteed unique for an AWS account; therefore, Chef will
# store the subnet ID associated with this name in your Chef server in the
# data bag `data/aws_subnet/<name>`.
#
# API documentation for the AWS Ruby SDK for VPCs (and the object returned from `aws_object` can be found here:
#
# - http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/Subnet.html
#
class Chef::Resource::AwsSubnet < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::EC2::Subnet

  require 'chef/resource/aws_vpc'
  require 'chef/resource/aws_route_table'

  #
  # The name of this subnet.
  #
  attribute :name, kind_of: String, name_attribute: true

  #
  # The VPC of this subnet.
  #
  # May be one of:
  # - The name of an `aws_vpc` Chef resource.
  # - An actual `aws_vpc` resource.
  # - An AWS `VPC` object.
  #
  attribute :vpc, kind_of: [ String, AwsVpc, AWS::EC2::VPC ]

  #
  # The CIDR block of IP addresses allocated to this subnet.
  # Must be a subset of the IP addresses in the VPC, and must not overlap the
  # IP addresses of any other subnet in the VPC.
  #
  # For example:
  # - `'10.0.0.0/24'` gives you 256 addresses.
  # - `'10.0.0.0/16'` gives you 65536 addresses.
  #
  # This defaults to taking all IP addresses in the VPC.
  #
  attribute :cidr_block, kind_of: String

  #
  # The availability zone of this subnet.
  #
  # e.g. us-east-1a or us-east-1b.
  #
  # By default, AWS will pick an AZ for a given subnet.
  #
  attribute :availability_zone, kind_of: String

  #
  # Whether to give public IP addresses to new instances in this subnet by default.
  #
  attribute :map_public_ip_on_launch, kind_of: [ TrueClass, FalseClass ]

  #
  # The route table to associate with this subnet.
  #
  # May be one of:
  # - The name of an `aws_route_table` Chef resource.
  # - An actual `aws_route_table` resource.
  # - An AWS `route_table` object.
  # - `:default_to_main`, which will detach any explicit route tables associated
  #   with the subnet, causing it to use the default (main) route table for the VPC.
  #
  # By default, an implicit association with the main route table is made (`:default_to_main`)
  #
  attribute :route_table#, kind_of: [ String, AwsRouteTable, AWS::EC2::RouteTable ], equal_to: [ :default_to_main ]

  attribute :subnet_id, kind_of: String, aws_id_attribute: true, lazy_default: proc {
    name =~ /^subnet-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2.subnets[id] if id
    if result
      begin
        # Try to access it to see if it exists (no `exists?` method)
        result.vpc_id
      rescue AWS::EC2::Errors::InvalidSubnetID::NotFound
        result = nil
      end
    end
    result
  end
end

require 'chef/provisioning/aws_driver/aws_resource_with_entry'

#
# An AWS peering connection, specifying which VPC to peer.
#
# `name` is not guaranteed unique for an AWS account; therefore, Chef will
# store the vpc peering connection ID associated with this name in your Chef server in the
# data bag `data/aws_vpc_peering_connection/<name>`.
#
# API documentation for the AWS Ruby SDK for VPC Peering Connections can be found here:
#
# - http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Types/VpcPeeringConnectionVpcInfo.html
#
class Chef::Resource::AwsVpcPeeringConnection < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type ::Aws::EC2::VpcPeeringConnection
  actions :accept, :create, :destroy, :purge, :nothing

  require 'chef/resource/aws_vpc'

  #
  # The name of this peering connection.
  #
  attribute :name, kind_of: String, name_attribute: true

  #
  # The Local VPC to peer
  #
  # May be one of:
  # - The name of an `aws_vpc` Chef resource.
  # - An actual `aws_vpc` resource.
  # - An AWS `VPC` object.
  #
  # This is required for new peering connections.
  #
  attribute :vpc, kind_of: [ String, AwsVpc, ::Aws::EC2::Vpc ]

  #
  # The VPC to peer
  #
  # May be one of:
  # - The name of an `aws_vpc` Chef resource.
  # - An actual `aws_vpc` resource.
  # - An AWS `VPC` object.
  # - The id of an AWS `VPC`.
  #
  # This is required for new peering connections.
  #
  attribute :peer_vpc, kind_of: [ String, AwsVpc, ::Aws::EC2::Vpc ]

  #
  # The target VPC account id to peer
  #
  # If not specified, will be assumed that the target VPC belongs to the current account.
  #
  attribute :peer_owner_id, kind_of: String

  attribute :vpc_peering_connection_id, kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^pcx-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2_resource.vpc_peering_connection(id) if id

    begin
      # try accessing it to find out if it exists
      result.requester_vpc if result
    rescue ::Aws::EC2::Errors::InvalidVpcPeeringConnectionIDNotFound
      result = nil
    end
    result
  end
end

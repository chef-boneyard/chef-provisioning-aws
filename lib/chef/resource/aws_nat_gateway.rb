#
# An AWS nat gateway, enable instances in a private subnet to connect to
# the Internet or other AWS services, but prevent the Internet from
# initiating a connection with those instances
#
# `name` is not guaranteed unique for an AWS account; therefore, Chef will
# store the nat gateway ID associated with this name in your Chef server in the
# data bag `data/aws_nat_gateway/<name>`.
#
# API documentation for the AWS Ruby SDK for Nat gateway can be found here:
#
# - http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Types/NatGateway.html
#

class Aws::EC2::NatGateway < Aws::Resources::Resource
  attr_reader :resource, :id, :nat_gateway_id, :vpc_id, :subnet_id, :nat_gateway_addresses

  def initialize(id, options = {})
    @id = id
    @nat_gateway_id = id
    @client = options[:client]
    nat_gateway_type = get_nat_gateway_type
    @vpc_id = nat_gateway_type.vpc_id
    @subnet_id = nat_gateway_type.subnet_id
    @nat_gateway_addresses = nat_gateway_type.nat_gateway_addresses
  end

  def state
    nat_gateway_type = get_nat_gateway_type
    nat_gateway_type.state
  end

  def delete
    @client.delete_nat_gateway({ nat_gateway_id: @id })
  end

  private
  def get_nat_gateway_type
    @client.describe_nat_gateways({ nat_gateway_ids: [@id] }).nat_gateways.first
  end
end

class Aws::EC2::Resource
  def create_nat_gateway(options)
    nat_gateway_type = self.client.create_nat_gateway(options).nat_gateway
    self.nat_gateway(nat_gateway_type.nat_gateway_id)
  end

  def nat_gateway(nat_gateway_id)
    Aws::EC2::NatGateway.new(nat_gateway_id, {client: client})
  end
end

class Chef::Resource::AwsNatGateway < Chef::Provisioning::AWSDriver::AWSResourceWithEntry

  aws_sdk_type ::Aws::EC2::NatGateway, id: :nat_gateway_id, managed_entry_id_name: 'nat_gateway_id'

  require 'chef/resource/aws_subnet'
  require 'chef/resource/aws_eip_address'

  #
  # The name of this nat gateway.
  #
  attribute :name, kind_of: String, name_attribute: true

  #
  # A vpc to attach to the internet gateway.
  #
  # May be one of:
  # - The name of an `aws_subnet` Chef resource.
  # - An actual `aws_subnet` resource.
  # - An Aws `Subnet` object.
  #
  attribute :subnet, kind_of: [ String, AwsSubnet, Aws::EC2::Subnet ]

  #
  # A elastic ip address for the nat gateway.
  #
  # May be one of:
  # - The name of an `aws_eip_address` Chef resource.
  # - An actual `aws_eip_address` resource.
  # - nil, meaning that no EIP exists yet and needs to be created.
  #
  attribute :eip_address, kind_of: [ String, AWS::EC2::ElasticIp, AwsEipAddress ], default: nil

  attribute :nat_gateway_id, kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^nat-[A-Fa-f0-9]{17}$/ ? name : nil
  }

  def aws_object
    driver, nat_gateway_id = get_driver_and_id
    result = driver.ec2_resource.nat_gateway(nat_gateway_id) if nat_gateway_id
    result && result.id ? result : nil
  end
end



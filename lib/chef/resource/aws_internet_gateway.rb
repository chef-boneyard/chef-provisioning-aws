#
# An AWS internet gateway, allowing communication between instances inside a VPC and the internet.
#
# `name` is not guaranteed unique for an AWS account; therefore, Chef will
# store the internet gateway ID associated with this name in your Chef server in the
# data bag `data/aws_internet_gateway/<name>`.
#
# API documentation for the AWS Ruby SDK for VPCs (and the object returned from `aws_object` can be found here:
#
# - http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/InternetGateway.html
#
class Chef::Resource::AwsInternetGateway < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::EC2::InternetGateway, id: :id

  require 'chef/resource/aws_vpc'

  #
  # Extend actions for the internet gateway
  #
  actions :create, :destroy, :detach, :purge

  #
  # The name of this internet gateway.
  #
  attribute :name, kind_of: String, name_attribute: true

  #
  # A vpc to attach to the internet gateway.
  #
  # May be one of:
  # - The name of an `aws_vpc` Chef resource.
  # - An actual `aws_vpc` resource.
  # - An AWS `VPC` object.
  #
  attribute :vpc, kind_of: [ String, AwsVpc, ::Aws::EC2::Vpc ]

  attribute :internet_gateway_id, kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^igw-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    ec2_resource = ::Aws::EC2::Resource.new(driver.ec2)
    result = ec2_resource.internet_gateway(id) if id
    result && exists?(result) ? result : nil
  end

  def exists?(result)
    return true if result.data
  rescue ::Aws::EC2::Errors::InvalidInternetGatewayIDNotFound
    return false
  end
end

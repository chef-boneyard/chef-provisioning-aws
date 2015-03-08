require 'chef/provisioning/aws_driver/aws_resource_with_entry'

class Chef::Resource::AwsSubnet < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::EC2::Subnet

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,              kind_of: String, name_attribute: true
  attribute :cidr_block,        kind_of: String
  attribute :vpc,               kind_of: String
  attribute :availability_zone, kind_of: String
  attribute :map_public_ip_on_launch, kind_of: [ TrueClass, FalseClass ]

  attribute :subnet_id, kind_of: String, aws_id_attribute: true, default {
    name =~ /^subnet-[a-f0-9]{8}$/ ? name : nil
  }

  protected

  def get_aws_object(driver, id)
    driver.ec2.subnets[id]
  end
end

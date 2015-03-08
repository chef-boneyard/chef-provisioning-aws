require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsVpc < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::EC2::VPC

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,             kind_of: String, name_attribute: true
  attribute :cidr_block,       kind_of: String
  attribute :instance_tenancy, equal_to: [ :default, :dedicated ], default: :default

  attribute :vpc_id, kind_of: String, aws_id_attribute: true, default {
    name =~ /^vpc-[a-f0-9]{8}$/ ? name : nil
  }

  protected

  def get_aws_object(driver, id)
    driver.ec2.vpcs[id]
  end
end

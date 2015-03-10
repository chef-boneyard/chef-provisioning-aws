require 'chef/provisioning/aws_driver/aws_resource_with_entry'

class Chef::Resource::AwsVpc < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::EC2::VPC

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,             kind_of: String, name_attribute: true
  attribute :cidr_block,       kind_of: String
  attribute :instance_tenancy, equal_to: [ :default, :dedicated ], default: :default

  attribute :vpc_id, kind_of: String, aws_id_attribute: true, lazy_default: proc {
    name =~ /^vpc-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2.vpcs[id] if id
    result && result.exists? ? result : nil
  end
end

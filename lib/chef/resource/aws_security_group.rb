require 'chef/provisioning/aws_driver/aws_resource_with_entry'

class Chef::Resource::AwsSecurityGroup < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::EC2::SecurityGroup

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,          kind_of: String, name_attribute: true
  attribute :vpc,           kind_of: String
  attribute :description,   kind_of: String
  attribute :inbound_rules
  attribute :outbound_rules

  attribute :security_group_id, kind_of: String, aws_id_attribute: true, default {
    name =~ /^sg-[a-f0-9]{8}$/ ? name : nil
  }

  protected

  def get_aws_object(driver, id)
    driver.ec2.security_groups[id]
  end
end

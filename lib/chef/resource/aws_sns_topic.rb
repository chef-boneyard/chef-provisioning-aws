require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsSnsTopic < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::SNS::Topic

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, kind_of: String, name_attribute: true
  attribute :arn,  kind_of: String, lazy_default: proc { build_arn('sns', name) }

  def aws_object
    result = driver.sns.topics[arn]
    result && result.exists? ? result : nil
  end
end

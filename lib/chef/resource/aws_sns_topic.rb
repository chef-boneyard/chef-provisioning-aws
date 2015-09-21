require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsSnsTopic < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::SNS::Topic

  attribute :name, kind_of: String, name_attribute: true
  attribute :arn,  kind_of: String, default: lazy { driver.build_arn(service: 'sns', resource: name) }

  def aws_object
    result = driver.sns.topics[arn]
    begin
      # Test whether it exists or not by asking for a property
      result.display_name
    rescue AWS::SNS::Errors::NotFound
      result = nil
    end
    result
  end
end

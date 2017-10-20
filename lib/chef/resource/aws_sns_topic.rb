require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsSnsTopic < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type ::Aws::SNS::Topic

  attribute :name, kind_of: String, name_attribute: true
  attribute :arn,  kind_of: String, default: lazy { driver.build_arn(service: 'sns', resource: name) }

  def aws_object
    begin
      # Test whether it exists or not by asking for a property
      result = driver.sns.get_topic_attributes(topic_arn: arn)
      result = result.data
    rescue ::Aws::SNS::Errors::NotFound
      result = nil
    end
    result
  end
end

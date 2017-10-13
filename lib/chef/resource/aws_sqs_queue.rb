require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsSqsQueue < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type ::Aws::SQS::Queue

  attribute :name,    kind_of: String, name_attribute: true
  attribute :options, kind_of: Hash

  def aws_object
    begin
      driver.sqs.get_queue_url(queue_name: name)
    rescue ::Aws::SQS::Errors::NonExistentQueue
      nil
    end
  end

  protected

  def self.get_aws_object_id(value, **options)
    aws_object = get_aws_object(value, **options)
    aws_object.arn.split(':')[-1] if aws_object
  end
end

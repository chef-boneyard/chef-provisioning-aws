require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsSqsQueue < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::SQS::Queue

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,    kind_of: String, name_attribute: true
  attribute :options, kind_of: Hash

  def aws_object
    begin
      driver.sqs.queues.named(name)
    rescue AWS::SQS::Errors::NonExistentQueue
      nil
    end
  end

  protected

  def self.aws_object_id(aws_object)
    aws_object.arn.split(':')[-1]
  end
end

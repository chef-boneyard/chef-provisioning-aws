require 'chef/provisioning/aws_driver/aws_provider'
require 'date'

class Chef::Provider::AwsSnsTopic < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_sns_topic
  
  protected

  def create_aws_object
    converge_by "create SNS topic #{new_resource.name} in #{region}" do
      new_resource.driver.sns.create_topic(name: new_resource.name)
    end
  end

  def update_aws_object(topic)
  end

  def destroy_aws_object(topic)
    topic_arn_name = topic.attributes.values_at("TopicArn").first
    converge_by "delete SNS topic_arn #{topic_arn_name} in #{region}" do
      new_resource.driver.sns.delete_topic(topic_arn: topic_arn_name)
    end
  end

end

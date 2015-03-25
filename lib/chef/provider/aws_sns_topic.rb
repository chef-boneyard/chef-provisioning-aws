require 'chef/provisioning/aws_driver/aws_provider'
require 'date'

class Chef::Provider::AwsSnsTopic < Chef::Provisioning::AWSDriver::AWSProvider

  protected

  def create_aws_object
    converge_by "Creating new SNS topic #{new_resource.name} in #{region}" do
      new_resource.driver.sns.topics.create(new_resource.name)
    end
  end

  def update_aws_object(topic)
  end

  def destroy_aws_object(topic)
    converge_by "Deleting SNS topic #{topic.name} in #{region}" do
      topic.delete
    end
  end

end

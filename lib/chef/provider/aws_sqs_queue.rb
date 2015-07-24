require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsSqsQueue < Chef::Provisioning::AWSDriver::AWSProvider

  def create_aws_object
    converge_by "create new SQS queue #{new_resource.name} in #{region}" do
      # TODO need timeout here.
      begin
        new_resource.driver.sqs.queues.create(new_resource.name, new_resource.options || {})
      rescue AWS::SQS::Errors::QueueDeletedRecently
        sleep 5
        retry
      end
    end
  end

  def update_aws_object(queue)
  end

  def destroy_aws_object(queue)
    converge_by "delete SQS queue #{new_resource.name} in #{region}" do
      queue.delete
    end
  end
end

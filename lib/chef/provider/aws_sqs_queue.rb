require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsSqsQueue < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_sqs_queue
  
  def create_aws_object
    converge_by "create SQS queue #{new_resource.name} in #{region}" do
      retry_with_backoff(AWS::SQS::Errors::QueueDeletedRecently) do
        new_resource.driver.sqs.queues.create(new_resource.name, new_resource.options || {})
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

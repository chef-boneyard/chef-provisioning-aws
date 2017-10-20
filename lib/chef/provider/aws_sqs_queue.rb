require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsSqsQueue < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_sqs_queue
  
  def create_aws_object
    options = AWSResource.lookup_options(new_resource.options || {}, resource: new_resource)
    option_sqs = {}
    option_sqs[:queue_name] = new_resource.name if new_resource.name
    option_sqs[:attributes] = options
    converge_by "create SQS queue #{new_resource.name} in #{region}" do
      retry_with_backoff(::Aws::SQS::Errors::QueueDeletedRecently) do
        new_resource.driver.sqs.create_queue(option_sqs)
      end
    end
  end

  def update_aws_object(queue)
  end

  def destroy_aws_object(queue)
    converge_by "delete SQS queue #{new_resource.name} in #{region}" do
      new_resource.driver.sqs.delete_queue(queue_url: queue.queue_url)
    end
  end
end

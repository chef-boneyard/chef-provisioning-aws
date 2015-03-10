require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsSqsQueue < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    aws_object = new_resource.aws_object
    if !aws_object
      converge_by "Creating new SQS queue #{new_resource.name} in #{region}" do
        loop do
          begin
            driver.sqs.queues.create(new_resource.name, new_resource.options || {})
            break
          rescue AWS::SQS::Errors::QueueDeletedRecently
            sleep 5
          end
        end
      end
    end
  end

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      converge_by "Deleting SQS queue #{new_resource.name} in #{region}" do
        aws_object.delete
      end
    end
  end

end

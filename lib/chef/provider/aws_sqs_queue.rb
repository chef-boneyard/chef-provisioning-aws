require 'chef/provider/aws_provider'

class Chef::Provider::AwsSqsQueue < Chef::Provider::AwsProvider

  action :create do
    if !current_aws_object
      converge_by "Creating new SQS queue #{new_resource.name} in #{region}" do
        loop do
          begin
            new_driver.sqs.queues.create(new_resource.name, new_resource.options)
            break
          rescue AWS::SQS::Errors::QueueDeletedRecently
            sleep 5
          end
        end
      end
    end
  end

  action :delete do
    if current_aws_object
      converge_by "Deleting SQS queue #{new_resource.name} in #{region}" do
        current_aws_object.delete
      end
    end
  end

end

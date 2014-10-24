require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsSqsQueue < Chef::Provider::AwsProvider

  action :create do
    if existing_queue == nil
      converge_by "Creating new SQS queue #{fqn} in #{new_resource.region_name}" do
        loop do
          begin
            sqs.queues.create(fqn)
            break
          rescue AWS::SQS::Errors::QueueDeletedRecently
            sleep 5
          end
        end

        new_resource.created_at DateTime.now.to_s
        new_resource.save
      end
    end
  end

  action :delete do
    if existing_queue
      converge_by "Deleting SQS queue #{fqn} in #{new_resource.region_name}" do
        existing_queue.delete
      end
    end

    new_resource.delete
  end

  def existing_queue
    @existing_queue ||= begin
      sqs.queues.named(fqn)
    rescue
      nil
    end
  end

  # Fully qualified queue name (i.e luigi:us-east-1)
  def id
    new_resource.queue_name
  end

end

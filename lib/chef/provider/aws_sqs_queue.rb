require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsSqsQueue < Chef::Provider::AwsProvider

  use_inline_resources

  include Chef::Mixin::ShellOut

  def initialize(*args)
    super
    credentials = @credentials.default
    AWS.config(:access_key_id => credentials[:aws_access_key_id],
               :secret_access_key => credentials[:aws_secret_access_key])

  end

  def whyrun_supported?
    true
  end

  action :create do
    if existing_queue == nil
      converge_by 'Create new SQS queue' do
        loop do
          begin
            sqs.queues.create(fqqn)
            break
          rescue AWS::SQS::Errors::QueueDeletedRecently
            sleep 5
          end
        end

        _fqqn = fqqn
        _region_name = new_resource.region_name
        Cheffish.inline_resource(self, :create) do
          chef_node "#{_fqqn}" do
            attribute 'region', _region_name
            attribute 'created_at', DateTime.now.to_s
          end
        end
      end
    end
  end

  action :delete do
    if existing_queue
      converge_by 'Deleting SQS queue' do
        existing_queue.delete
      end
    end

    # TODO: mark removal time so we can honor the 60s wait time to re-create
    _fqqn = fqqn
    Cheffish.inline_resource(self, :delete) do
      chef_node "#{_fqqn}" do
        action :delete
      end
    end
  end

  def existing_queue
    @existing_queue ||= begin
      sqs.queues.named(fqqn)
    rescue
      nil
    end
  end

  # Fully qualified queue name (i.e luigi:us-east-1)
  def fqqn
    if new_resource.queue_name
      new_resource.queue_name
    else
      "#{new_resource.name}_#{new_resource.region_name}"
    end
  end

  def sqs
    credentials = @credentials.default
    region = new_resource.region_name || credentials[:region]
    # Pivot region
    AWS.config(:region => region)
    @sqs ||= AWS::SQS.new
  end

  def load_current_resource
  end
end

require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsSnsTopic < Chef::Provider::AwsProvider

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
    if existing_topic == nil
      converge_by 'Create new SNS topic' do
        sns.topics.create(fqtn)

        _fqtn = fqtn
        _region_name = new_resource.region_name
        Cheffish.inline_resource(self, :create) do
          chef_node "#{_fqtn}" do
            attribute 'region', _region_name
            attribute 'created_at', DateTime.now.to_s
          end
        end
      end
    end
  end

  action :delete do
    if existing_topic
      converge_by 'Deleting SNS topic' do
        existing_topic.delete
      end
    end

    # TODO: mark removal time so we can honor the 60s wait time to re-create
    _fqtn = fqtn
    Cheffish.inline_resource(self, :delete) do
      chef_node "#{_fqtn}" do
        action :delete
      end
    end
  end

  def existing_topic
    @existing_topic ||= begin
      sns.topics.named(fqtn)
    rescue
      nil
    end
  end

  # Fully qualified topic name (i.e luigi:us-east-1)
  def fqtn
    if new_resource.topic_name
      new_resource.topic_name
    else
      "#{new_resource.name}_#{new_resource.region_name}"
    end
  end

  def sns
    credentials = @credentials.default
    region = new_resource.region_name || credentials[:region]
    # Pivot region
    AWS.config(:region => region)
    @sns ||= AWS::SNS.new
  end

  def load_current_resource
  end
end

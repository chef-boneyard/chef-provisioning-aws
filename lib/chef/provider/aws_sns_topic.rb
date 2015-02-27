require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsSnsTopic < Chef::Provider::AwsProvider

  action :create do
    if existing_topic == nil
      converge_by "Creating new SNS topic #{fqn} in #{new_driver.aws_config.region}" do
        new_driver.sns.topics.create(fqn)

        new_resource.created_at DateTime.now.to_s
        new_resource.save
      end
    end
  end

  action :delete do
    if existing_topic
      converge_by "Deleting SNS topic #{fqn} in #{new_driver.aws_config.region}" do
        existing_topic.delete
      end
    end

    new_resource.delete
  end

  def existing_topic
    @existing_topic ||= begin
      new_driver.sns.topics.named(fqn)
    rescue
      nil
    end
  end

  def id
    new_resource.topic_name
  end

end

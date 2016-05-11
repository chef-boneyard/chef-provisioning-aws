require 'chef/provisioning/aws_driver/aws_tagger'

module Chef::Provisioning::AWSDriver::TaggingStrategy
  module AutoScalingConvergeTags
    def aws_tagger
      @aws_tagger ||= begin
        auto_scaling_strategy = Chef::Provisioning::AWSDriver::TaggingStrategy::AutoScaling.new(
          new_resource.driver.auto_scaling_client,
          new_resource.name,
          new_resource.aws_tags
        )
        Chef::Provisioning::AWSDriver::AWSTagger.new(auto_scaling_strategy, action_handler)
      end
    end
    def converge_tags
      aws_tagger.converge_tags
    end
  end
end

module Chef::Provisioning::AWSDriver::TaggingStrategy
class AutoScaling

  attr_reader :auto_scaling_client, :group_name, :desired_tags

  def initialize(auto_scaling_client, group_name, desired_tags)
    @auto_scaling_client = auto_scaling_client
    @group_name = group_name
    @desired_tags = desired_tags
  end

  def current_tags
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/AutoScaling/Client.html#describe_tags-instance_method
    resp = auto_scaling_client.describe_tags({
      filters: [
        {
          name: "auto-scaling-group",
          values: [group_name]
        }
      ]
    })
    Hash[resp.tags.map {|t| [t.key, t.value]}]
  end

  def set_tags(tags)
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/AutoScaling/Client.html#create_or_update_tags-instance_method
    auto_scaling_client.create_or_update_tags({
      tags: tags.map {|k,v|
        {
          resource_id: group_name,
          key: k,
          value: v,
          resource_type: "auto-scaling-group",
          propagate_at_launch: false
        }
      }
    })
  end

  def delete_tags(tag_keys)
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/AutoScaling/Client.html#delete_tags-instance_method
    auto_scaling_client.delete_tags({
      tags: tag_keys.map {|k|
        {
          resource_id: group_name,
          key: k,
          value: nil,
          resource_type: "auto-scaling-group",
          propagate_at_launch: false
        }
      }
    })
  end

end
end

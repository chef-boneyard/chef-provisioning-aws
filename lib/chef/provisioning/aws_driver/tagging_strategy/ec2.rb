require 'chef/provisioning/aws_driver/aws_tagger'

module Chef::Provisioning::AWSDriver::TaggingStrategy
  module EC2ConvergeTags
    def aws_tagger
      @aws_tagger ||= begin
        ec2_strategy = Chef::Provisioning::AWSDriver::TaggingStrategy::EC2.new(
          new_resource.driver.ec2_client,
          new_resource.aws_object_id,
          new_resource.aws_tags
        )
        Chef::Provisioning::AWSDriver::AWSTagger.new(ec2_strategy, action_handler)
      end
    end
    def converge_tags
      aws_tagger.converge_tags
    end
  end
end

module Chef::Provisioning::AWSDriver::TaggingStrategy
class EC2

  attr_reader :ec2_client, :aws_object_id, :desired_tags

  def initialize(ec2_client, aws_object_id, desired_tags)
    @ec2_client = ec2_client
    @aws_object_id = aws_object_id
    @desired_tags = desired_tags
  end

  def current_tags
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Client.html#describe_tags-instance_method
    resp = ec2_client.describe_tags({
      filters: [
        {
          name: "resource-id",
          values: [aws_object_id]
        }
      ]
    })
    Hash[resp.tags.map {|t| [t.key, t.value]}]
  end

  def set_tags(tags)
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Client.html#create_tags-instance_method
    # "The value parameter is required, but if you don't want the tag to have a value, specify
    #   the parameter with no value, and we set the value to an empty string."
    ec2_client.create_tags({
      resources: [aws_object_id],
      tags: tags.map {|k,v| {key: k, value: v} }
    })
  end

  def delete_tags(tag_keys)
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Client.html#delete_tags-instance_method
    ec2_client.delete_tags({
      resources: [aws_object_id],
      tags: tag_keys.map {|k| {key: k} }
    })
  end

end
end

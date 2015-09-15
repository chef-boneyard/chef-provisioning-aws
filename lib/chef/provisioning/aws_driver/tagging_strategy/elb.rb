require 'chef/provisioning/aws_driver/aws_tagger'

module Chef::Provisioning::AWSDriver::TaggingStrategy
class ELB

  attr_reader :elb_client, :access_point_name, :desired_tags

  def initialize(elb_client, access_point_name, desired_tags)
    @elb_client = elb_client
    @access_point_name = access_point_name
    @desired_tags = desired_tags
  end

  def current_tags
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/ElasticLoadBalancing/Client.html#describe_tags-instance_method
    resp = elb_client.describe_tags({
      load_balancer_names: [access_point_name]
    })
    Hash[resp.tag_descriptions[0].tags.map {|t| [t.key, t.value]}]
  end

  def set_tags(tags)
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/ElasticLoadBalancing/Client.html#add_tags-instance_method
    elb_client.add_tags({
      load_balancer_names: [access_point_name],
      tags: tags.map {|k,v| {key: k, value: v} }
    })
  end

  def delete_tags(tag_keys)
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/ElasticLoadBalancing/Client.html#remove_tags-instance_method
    elb_client.remove_tags({
      load_balancer_names: [access_point_name],
      tags: tag_keys.map {|k| {key: k} }
    })
  end

end
end

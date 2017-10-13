require 'chef/provisioning/aws_driver/aws_tagger'

####################
# NOTE FROM http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Tagging.html
# "Note that tags are cached for authorization purposes. Because of this, additions
#  and updates to tags on Amazon RDS resources may take several minutes before they
#  are available."
####################

module Chef::Provisioning::AWSDriver::TaggingStrategy
  module RDSConvergeTags
    def aws_tagger
      @aws_tagger ||= begin
        rds_strategy = Chef::Provisioning::AWSDriver::TaggingStrategy::RDS.new(
          new_resource.driver.rds,
          construct_arn(new_resource),
          new_resource.aws_tags
        )
        Chef::Provisioning::AWSDriver::AWSTagger.new(rds_strategy, action_handler)
      end
    end
    def converge_tags
      aws_tagger.converge_tags
    end

    # http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Tagging.html#USER_Tagging.ARN
    def construct_arn(new_resource)
      @arn ||= begin
        region = new_resource.driver.aws_config[:region]
        name = new_resource.name
        rds_type = new_resource.rds_tagging_type
        # Taken from example on https://forums.aws.amazon.com/thread.jspa?threadID=108012
        account_id = begin
          u = new_resource.driver.iam.get_user
          # We've got an AWS account root credential or an IAM admin with access rights
          u[:user][:arn].match('^arn:aws:iam::([0-9]{12}):.*$')[1]
        rescue ::Aws::IAM::Errors::AccessDenied => e
          # We've got an AWS IAM Credential
          e.to_s.match('^User: arn:aws:iam::([0-9]{12}):.*$')[1]
        end
        # arn:aws:rds:<region>:<account number>:<resourcetype>:<name>
        "arn:aws:rds:#{region}:#{account_id}:#{rds_type}:#{name}"
      end
    end
  end
end

module Chef::Provisioning::AWSDriver::TaggingStrategy
class RDS

  attr_reader :rds_client, :rds_object_arn, :desired_tags

  def initialize(rds_client, rds_object_arn, desired_tags)
    @rds_client = rds_client
    @rds_object_arn = rds_object_arn
    @desired_tags = desired_tags
  end

  def current_tags
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/RDS/Client.html#list_tags_for_resource-instance_method
    resp = rds_client.list_tags_for_resource({
      resource_name: rds_object_arn
    })
    Hash[resp.tag_list.map {|t| [t.key, t.value]}]
  end

  def set_tags(tags)
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/RDS/Client.html#add_tags_to_resource-instance_method
    # Unlike EC2, RDS tags can have a nil value
    tags = tags.map {|k,v|
      if v.nil?
        {key: k}
      else
        {key: k, value: v}
      end
    }
    rds_client.add_tags_to_resource({
      resource_name: rds_object_arn,
      tags: tags
    })
  end

  def delete_tags(tag_keys)
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/RDS/Client.html#remove_tags_from_resource-instance_method
    rds_client.remove_tags_from_resource({
      resource_name: rds_object_arn,
      tag_keys: tag_keys
    })
  end

end
end

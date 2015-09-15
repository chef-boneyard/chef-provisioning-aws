require_relative 'aws_resource'

module Chef::Provisioning::AWSDriver
class AWSRDSResource < AWSResource

  def rds_tagging_type
    raise "You must add the RDS resource type lookup from http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Tagging.html#USER_Tagging.ARN"
  end

end
end

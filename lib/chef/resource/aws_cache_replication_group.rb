require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/resource/aws_security_group'

class Chef::Resource::AwsCacheReplicationGroup < Chef::Provisioning::AWSDriver::AWSResource
  # Note: There isn't actually an SDK class for Elasticache.
  aws_sdk_type AWS::ElastiCache

  # See http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/ElastiCache/Client/V20140930.html#create_replication_group-instance_method
  # for information on possible values for each attribute. Values are passed
  # straight through to AWS, with the exception of security_groups, which
  # may contain a reference to a Chef aws_security_group resource.
  attribute :group_name, kind_of: String, name_attribute: true
  attribute :description, kind_of: String, required: true
  attribute :automatic_failover, kind_of: [TrueClass, FalseClass], default: false
  attribute :number_cache_clusters, kind_of: Integer, default: 2
  attribute :node_type, kind_of: String, required: true
  attribute :engine, kind_of: String, required: true
  attribute :engine_version, kind_of: String, required: true
  attribute :subnet_group_name, kind_of: String
  attribute :security_groups,
            kind_of: [ String, Array, AwsSecurityGroup, AWS::EC2::SecurityGroup ],
            required: true,
            coerce: proc { |v| [v].flatten }
  attribute :preferred_availability_zones,
            kind_of: [ String, Array ],
            coerce: proc { |v| [v].flatten }

  def aws_object
    begin
      driver.elasticache
        .describe_replication_groups(replication_group_id: group_name)
        .data[:replication_groups].first
    rescue AWS::ElastiCache::Errors::ReplicationGroupNotFoundFault
      nil
    end
  end
end

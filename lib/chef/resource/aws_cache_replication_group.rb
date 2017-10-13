require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/resource/aws_security_group'

# AWS Elasticache Replication Group
# @see See http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/ElastiCache/Client/V20140930.html#create_replication_group-instance_method
class Chef::Resource::AwsCacheReplicationGroup < Chef::Provisioning::AWSDriver::AWSResource
  # Note: There isn't actually an SDK class for Elasticache.
  aws_sdk_type ::Aws::ElastiCache

  # See http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/ElastiCache/Client/V20140930.html#create_replication_group-instance_method
  # for information on possible values for each attribute. Values are passed
  # straight through to AWS, with the exception of security_groups, which
  # may contain a reference to a Chef aws_security_group resource.

  # Group Name
  #
  # @param :group_name [String] Elasticache replication group name.
  attribute :group_name, kind_of: String, name_attribute: true

  # Replication group description
  #
  # @param :description [String] Elasticache replication group description.
  attribute :description, kind_of: String, required: true

  # Automatic failover
  #
  # @param :automatic_failover [Boolean] Whether a read replica will be automatically promoted to read/write primary if the existing primary encounters a failure.
  attribute :automatic_failover, kind_of: [TrueClass, FalseClass], default: false

  # Number of cache clusters
  #
  # @param :number_cache_clusters [Integer] Number of cache clusters.
  attribute :number_cache_clusters, kind_of: Integer, default: 2

  # Node type
  #
  # @param :node_type [String] AWS node type for each replication group.
  attribute :node_type, kind_of: String, required: true

  # Engine
  #
  # @param :engine [String] Valid values are `memcached` or `redis`.
  attribute :engine, kind_of: String, required: true

  # Engine Version
  #
  # @param :engine_version [String] The version number of the cache engine.
  attribute :engine_version, kind_of: String, required: true

  # Subnet group name
  #
  # @param :subnet_group_name [String] Cache cluster aws_cache_subnet_group.
  attribute :subnet_group_name, kind_of: String

  # Security Groups
  #
  # @param
  attribute :security_groups,
            kind_of: [ String, Array, AwsSecurityGroup, ::Aws::EC2::SecurityGroup ],
            required: true,
            coerce: proc { |v| [v].flatten }

  # Group Name
  #
  # @param
  attribute :preferred_availability_zones,
            kind_of: [ String, Array ],
            coerce: proc { |v| [v].flatten }

  def aws_object
    begin
      driver.elasticache
        .describe_replication_groups(replication_group_id: group_name)
        .data[:replication_groups].first
    rescue ::Aws::ElastiCache::Errors::ReplicationGroupNotFoundFault
      nil
    end
  end
end

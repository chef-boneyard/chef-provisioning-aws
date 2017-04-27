require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/resource/aws_security_group'

# AWS Elasticache Cluster
#
# @see http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/ElastiCache/Client/V20140930.html#create_cache_cluster-instance_method
class Chef::Resource::AwsCacheCluster < Chef::Provisioning::AWSDriver::AWSResource
  # Note: There isn't actually an SDK class for Elasticache.
  aws_sdk_type ::Aws::ElastiCache

  # See http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/ElastiCache/Client/V20140930.html#create_cache_cluster-instance_method
  # for information on possible values for each attribute. Values are passed
  # straight through to AWS, with the exception of security_groups, which
  # may contain a reference to a Chef aws_security_group resource.

  # Cluster Name
  #
  # @param :cluster_name [String] unique name for a cluster
  attribute :cluster_name, kind_of: String, name_attribute: true

  # Availability Zone
  #
  # @param :az_mode [String] Specifies whether the nodes in this Memcached node group are created in a single Availability Zone or created across multiple Availability Zones in the cluster's region. This parameter is only supported for Memcached cache clusters. If the AZMode and PreferredAvailabilityZones are not specified, ElastiCache assumes single-az mode.
  attribute :az_mode, kind_of: String

  # Preferred Availability Zone
  #
  # @param :preferred_availability_zone [String] preferred availability zone of the cache cluster
  attribute :preferred_availability_zone, kind_of: String

  # Preferred Availability Zones
  #
  # @param :preferred_availability_zones [String, Array] One or more preferred availability zones
  attribute :preferred_availability_zones,
            kind_of: [ String, Array ],
            coerce: proc { |v| [v].flatten }


  # Number of Nodes
  #
  # @param :number_nodes [Integer] Number of nodes in the cache
  attribute :number_nodes, kind_of: Integer, default: 1

  # Node type
  #
  # @param :node_type [String] AWS node type for each cache cluster node
  attribute :node_type, kind_of: String, required: true

  # Engine
  #
  # @param :engine [String] Valid values are `memcached` or `redis`
  attribute :engine, kind_of: String, required: true

  # Engine Version
  #
  # @param :engine_version [String] The version number of the cache engine to be used for this cache cluster.
  attribute :engine_version, kind_of: String, required: true

  # Subnet Group Name
  #
  # @param :subnet_group_name [String] Cache cluster aws_cache_subnet_group
  attribute :subnet_group_name, kind_of: String

  # Security Groups
  #
  # @param :security_groups [String, Array, AwsSecurityGroup, ::Aws::EC2::SecurityGroup] one or more VPC security groups associated with the cache cluster.
  attribute :security_groups,
            kind_of: [ String, Array, AwsSecurityGroup, ::Aws::EC2::SecurityGroup ],
            required: true,
            coerce: proc { |v| [v].flatten }

  def aws_object
    begin
      driver.elasticache
        .describe_cache_clusters(cache_cluster_id: cluster_name)
        .data[:cache_clusters].first
    rescue ::Aws::ElastiCache::Errors::CacheClusterNotFound
      nil
    end
  end
end

require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/resource/aws_security_group'

class Chef::Resource::AwsCacheCluster < Chef::Provisioning::AWSDriver::AWSResource
  # Note: There isn't actually an SDK class for Elasticache.
  aws_sdk_type AWS::ElastiCache

  # See http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/ElastiCache/Client/V20140930.html#create_cache_cluster-instance_method
  # for information on possible values for each attribute. Values are passed
  # straight through to AWS, with the exception of security_groups, which
  # may contain a reference to a Chef aws_security_group resource.
  attribute :cluster_name, kind_of: String, name_attribute: true
  attribute :az_mode, kind_of: String
  attribute :preferred_availability_zone, kind_of: String
  attribute :preferred_availability_zones,
            kind_of: [ String, Array ],
            coerce: proc { |v| [v].flatten }
  attribute :number_nodes, kind_of: Integer, default: 1
  attribute :node_type, kind_of: String, required: true
  attribute :engine, kind_of: String, required: true
  attribute :engine_version, kind_of: String, required: true
  attribute :subnet_group_name, kind_of: String
  attribute :security_groups,
            kind_of: [ String, Array, AwsSecurityGroup, AWS::EC2::SecurityGroup ],
            required: true,
            coerce: proc { |v| [v].flatten }

  def aws_object
    begin
      driver.elasticache
        .describe_cache_clusters(cache_cluster_id: cluster_name)
        .data[:cache_clusters].first
    rescue AWS::ElastiCache::Errors::CacheClusterNotFound
      nil
    end
  end
end

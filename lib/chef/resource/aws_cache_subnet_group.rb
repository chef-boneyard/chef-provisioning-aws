require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/resource/aws_subnet'

# AWS Elasticache Subnet Group
# @see http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/ElastiCache/Client/V20140930.html#create_cache_subnet_group-instance_method
class Chef::Resource::AwsCacheSubnetGroup < Chef::Provisioning::AWSDriver::AWSResource
  # Note: There isn't actually an SDK class for Elasticache.
  aws_sdk_type ::Aws::ElastiCache, id: :group_name

  # See http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/ElastiCache/Client/V20140930.html#create_cache_subnet_group-instance_method
  # for information on possible values for each attribute. Values are passed
  # straight through to AWS, with the exception of subnets, which
  # may contain a reference to a Chef aws_subnet resource.

  # Group Name
  #
  # @param :group_name [String] The name of the cache subnet group to be used for the replication group.
  attribute :group_name, kind_of: String, name_attribute: true

  # Description
  #
  # @param :description [String] Subnet group description.
  attribute :description, kind_of: String, required: true

  # Subnets
  #
  # @param :subnets [ String, Array, AwsSubnet, ::Aws::EC2::Subnet ] One or more subnets in the subnet group.
  attribute :subnets,
            kind_of: [ String, Array, AwsSubnet, ::Aws::EC2::Subnet ],
            required: true,
            coerce: proc { |v| [v].flatten }

  def aws_object
    begin
      driver.elasticache
        .describe_cache_subnet_groups(cache_subnet_group_name: group_name)
        .data[:cache_subnet_groups].first
    rescue ::Aws::ElastiCache::Errors::CacheSubnetGroupNotFoundFault
      nil
    end
  end
end

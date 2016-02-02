require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsCacheReplicationGroup < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_cache_replication_group
  
  protected

  def create_aws_object
    converge_by "create ElastiCache replication group #{new_resource.name} in #{region}" do
      driver.create_replication_group(desired_options)
    end
  end

  def update_aws_object(cache_replication_group)
    Chef::Log.warn('Updating ElastiCache replication groups is currently unsupported')
  end

  def destroy_aws_object(cache_replication_group)
    converge_by "delete ElastiCache replication group #{new_resource.name} in #{region}" do
      driver.delete_replication_group(
        replication_group_id: cache_replication_group[:replication_group_id]
      )
    end
  end

  private

  def driver
    new_resource.driver.elasticache
  end

  def desired_options
    @desired_options ||= begin
      options = {}
      options[:replication_group_id] = new_resource.group_name
      options[:replication_group_description] = new_resource.description
      options[:automatic_failover_enabled] = new_resource.automatic_failover
      options[:num_cache_clusters] = new_resource.number_cache_clusters
      options[:cache_node_type] = new_resource.node_type
      options[:engine] = new_resource.engine
      options[:engine_version] = new_resource.engine_version
      options[:preferred_cache_cluster_a_zs] =
        new_resource.preferred_availability_zones if new_resource.preferred_availability_zones
      options[:cache_subnet_group_name] =
        new_resource.subnet_group_name if new_resource.subnet_group_name
      options[:security_group_ids] = new_resource.security_groups
      AWSResource.lookup_options(options, resource: new_resource)
    end
  end
end

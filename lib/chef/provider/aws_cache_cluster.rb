require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsCacheCluster < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_cache_cluster

  protected

  def create_aws_object
    converge_by "create ElastiCache cluster #{new_resource.name} in #{region}" do
      driver.create_cache_cluster(desired_options)
    end
  end

  def update_aws_object(cache_cluster)
    if update_required?(cache_cluster)
      converge_by "update Elasticache Cluster #{new_resource.name} in #{region}" do
        driver.modify_cache_cluster(
          updatable_options(desired_options).merge(
            cache_cluster_id: cache_cluster[:cache_cluster_id]
          )
        )
      end
    end
  end

  def destroy_aws_object(cache_cluster)
    converge_by "delete ElastiCache cluster #{new_resource.name} in #{region}" do
      driver.delete_cache_cluster(
        cache_cluster_id: cache_cluster[:cache_cluster_id]
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
      options[:cache_cluster_id] = new_resource.cluster_name
      options[:num_cache_nodes] = new_resource.number_nodes
      options[:cache_node_type] = new_resource.node_type
      options[:engine] = new_resource.engine
      options[:az_mode] = new_resource.az_mode if new_resource.az_mode
      options[:preferred_availability_zone] =
        new_resource.preferred_availability_zone if new_resource.preferred_availability_zone
      options[:preferred_availability_zones] =
        new_resource.preferred_availability_zones if new_resource.preferred_availability_zones
      options[:engine_version] = new_resource.engine_version
      options[:cache_subnet_group_name] =
        new_resource.subnet_group_name if new_resource.subnet_group_name
      options[:security_group_ids] = new_resource.security_groups
      AWSResource.lookup_options(options, resource: new_resource)
    end
  end

  def updatable_options(options)
    updatable = [:security_groups, :num_cache_nodes, :engine_version]
    options.delete_if { |option, _value| !updatable.include?(option) }
  end

  def update_required?(cache_cluster)
    current_sg_ids = cache_cluster[:security_groups].map { |sg| sg[:security_group_id] }.sort

    if desired_options[:security_group_ids].sort != current_sg_ids ||
      desired_options[:num_cache_nodes] != cache_cluster[:num_cache_nodes] ||
      desired_options[:engine_version] != cache_cluster[:engine_version]
      true
    else
      false
    end
  end
end

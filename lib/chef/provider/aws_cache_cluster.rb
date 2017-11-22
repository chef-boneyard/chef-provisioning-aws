require 'chef/provisioning/aws_driver/aws_provider'
require 'retryable'

class Chef::Provider::AwsCacheCluster < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_cache_cluster

  class CacheClusterStatusTimeoutError < ::Timeout::Error
    def initialize(new_resource, initial_status, expected_status)
      super("timed out waiting for #{new_resource} status to change from #{initial_status} to #{expected_status}!")
    end
  end

  protected

  def create_aws_object
    converge_by "create ElastiCache cluster #{new_resource.name} in #{region}" do
      cluster_obj = driver.create_cache_cluster(desired_options)
      # waiting for 10 minutes as the cache cluster takes time to become available
      wait_for_cache_cluster_state(cluster_obj.cache_cluster, :available, 10, 60)
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

  def wait_for_cache_cluster_state(aws_object, expected_status, tries=60, sleep=5)
    query_method = :cache_cluster_status

    Retryable.retryable(:tries => tries, :sleep => sleep) do |retries, exception|
      action_handler.report_progress "waited #{retries*sleep}/#{tries*sleep}s for <#{aws_object.class}:#{aws_object.cache_cluster_id}>##{query_method} state to change to #{expected_status}..."
      Chef::Log.debug("Current exception in wait_for is #{exception.inspect}") if exception
      cache_cluster =  new_resource.driver.elasticache.describe_cache_clusters(cache_cluster_id: aws_object.cache_cluster_id)
      status = cache_cluster.cache_clusters.first.cache_cluster_status
      action_handler.report_progress "Current Cluster Status: #{status}"
      raise CacheClusterStatusTimeoutError.new(aws_object, status, expected_status) if status != expected_status.to_s
    end
  end
end

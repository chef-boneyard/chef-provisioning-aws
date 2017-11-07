require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsCacheSubnetGroup < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_cache_subnet_group

  protected

  def create_aws_object
    converge_by "create ElastiCache subnet group #{new_resource.name} in #{region}" do
      driver.create_cache_subnet_group(desired_options)
    end
  end

  def update_aws_object(cache_subnet_group)
    if update_required?(cache_subnet_group)
      converge_by "update ElastiCache subnet group #{new_resource.name} in #{region}" do
        driver.modify_cache_subnet_group(desired_options)
      end
    end
  end

  def destroy_aws_object(cache_subnet_group)
    converge_by "delete ElastiCache subnet group #{new_resource.name} in #{region}" do
      driver.delete_cache_subnet_group(
        cache_subnet_group_name: cache_subnet_group[:cache_subnet_group_name]
      )
    end
  end

  private

  def driver
    new_resource.driver.elasticache
  end

  def update_cache_subnet_group
    new_resource.driver.elasticache.modify_cache_subnet_group(desired_options)
  end

  def desired_options
    @desired_options ||= begin
      options = {}
      options[:cache_subnet_group_name] = new_resource.group_name
      options[:cache_subnet_group_description] = new_resource.description
      options[:subnet_ids] = new_resource.subnets
      AWSResource.lookup_options(options, resource: new_resource)
    end
  end

  def update_required?(cache_subnet_group)
    current_subnet_ids = cache_subnet_group[:subnets]
                           .map { |subnet| subnet[:subnet_identifier] }.sort
    current_description = cache_subnet_group[:cache_subnet_group_description]
    if new_resource.description != current_description ||
      desired_options[:subnet_ids].sort != current_subnet_ids
      true
    else
      false
    end
  end
end

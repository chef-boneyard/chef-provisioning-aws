require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsCloudsearchDomain < Chef::Provisioning::AWSDriver::AWSProvider

  def create_aws_object
    converge_by "Creating new CloudSearch domain #{new_resource.domain_name}" do
      create_domain
    end
    # multi_az defaults to false on creation
    # so we only need to hit the API if it is true
    if new_resource.multi_az
      converge_by "Setting availability options for CloudSearch domain #{new_resource}" do
        update_availability_options
      end
    end

    if update_scaling_params?
      converge_by "Setting scaling parameters for CloudSearch domain #{new_resource.domain_name}" do
        update_scaling_parameters
      end
    end

    if update_policy?
      converge_by "Setting access policy for CloudSearch domain #{new_resource.domain_name}" do
        update_service_access_policy
      end
    end

    if update_index_fields?
      converge_by "Defining index fields for CloudSearch domain #{new_resource.domain_name}" do
        new_resource.index_fields.each do |idx_field|
          if !idx_field.is_a? Hash
            raise ArgumentError, "Expected index_fields to contain only Hashes"
          else
            create_index_field(idx_field)
          end
        end
      end
    end
  end

  def destroy_aws_object(instance)
    converge_by "Deleting CloudSearch domain #{new_resource.domain_name}" do
      cs_client.delete_domain(domain_name: new_resource.domain_name)
    end
  end

  def update_aws_object(instance)
    if update_availability_options?
      converge_by "Updating availability options for CloudSearch domain #{new_resource}" do
        update_availability_options
      end
    end

    if update_scaling_params?
      converge_by "Updating scaling parameters for CloudSearch domain #{new_resource.domain_name}" do
        update_scaling_parameters
      end
    end

    if update_policy?
      converge_by "Updating access policy for CloudSearch domain #{new_resource.domain_name}" do
        update_service_access_policy
      end
    end

    if update_index_fields?
      Chef::Log.warn("Updating existing index_fields not currently supported")
    end
  end


  # TODO(ssd): Expand these to be idempotent?  It takes an extra API
  # call just to see the current settings so it feels cheaper to just
  # set them anyway, but then you get updated resources.
  def update_availability_options?
    ! new_resource.multi_az.nil?
  end

  def update_scaling_params?
    ! (new_resource.partition_count.nil? || new_resource.replication_count.nil? || new_resource.instance_type.nil?)
  end

  def update_policy?
    ! new_resource.access_policies.nil?
  end

  def update_index_fields?
    ! new_resource.index_fields.nil?
  end

  def create_domain
    cs_client.create_domain(domain_name: new_resource.domain_name)
  end

  def update_availability_options
    cs_client.update_availability_options(domain_name: new_resource.domain_name,
                                          multi_az: new_resource.multi_az)
  end

  def update_scaling_parameters
    cs_client.update_scaling_parameters(domain_name: new_resource.domain_name,
                                        scaling_parameters: scaling_params)
  end

  def update_service_access_policy
    cs_client.update_service_access_policies(domain_name: new_resource.domain_name,
                                             access_policies: new_resource.access_policies)
  end

  def create_index_field(field)
    cs_client.define_index_field(domain_name: new_resource.domain_name, index_field: field)
  end

  def scaling_parameters
    {
      desired_partition_count: new_resource.partion_count,
      desired_replication_count: new_resource.replication_count,
      desired_instance_type: new_resource.instance_type
    }
  end

  def cs_client
    @cs_client ||= new_resource.driver.cloudsearch(new_resource.cloudsearch_api_version)
  end
end

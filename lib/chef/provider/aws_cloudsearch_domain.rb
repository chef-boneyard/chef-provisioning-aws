require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsCloudsearchDomain < Chef::Provisioning::AWSDriver::AWSProvider

  def create_aws_object
    domain = nil # define here to ensure it is available outside of the coverge_by scope
    converge_by "Creating new CloudSearch domain #{new_resource.domain_name}" do
      domain = create_domain
    end

    update_aws_object(domain)
  end

  def destroy_aws_object(instance)
    converge_by "Deleting CloudSearch domain #{new_resource.domain_name}" do
      cs_client.delete_domain(domain_name: new_resource.domain_name)
    end
  end

  def update_aws_object(instance)
    if update_availability_options?(instance)
      converge_by "Updating availability options for CloudSearch domain #{new_resource}" do
        update_availability_options
      end
    end

    if update_scaling_params?(instance)
      converge_by "Updating scaling parameters for CloudSearch domain #{new_resource.domain_name}" do
        update_scaling_parameters
      end
    end

    if update_policy?(instance)
      converge_by "Updating access policy for CloudSearch domain #{new_resource.domain_name}" do
        update_service_access_policy
      end
    end

    if update_index_fields?(instance)
      Chef::Log.warn("Updating existing index_fields not currently supported")
    end
  end

  private

  def update_availability_options?(_instance)
    # new_resource.multi_az defaults to false so we don't need an existence check
    new_resource.multi_az != availability_options
  end

  def update_scaling_params?(instance)
    if new_resource.partition_count || new_resource.replication_count || new_resource.instance_type
      # We don't want to change scaling parameters that the user
      # didn't specify Thus, we compare on a key-by-key basis.  Only
      # user-specified keys show up in desired_scaling_parameters
      actual_scaling_parameters = scaling_parameters(instance)
      desired_scaling_parameters.each do |key, value|
        return true if value != actual_scaling_parameters[key]
      end
      false
    else
      false
    end
  end

  def update_policy?(_instance)
    if !new_resource.access_policies.nil?
      new_resource.access_policies != access_policies
    else
      false
    end
  end

  def update_index_fields?(instance)
    if ! new_resource.index_fields.nil?
      new_resource.index_fields != index_fields
    else
      false
    end
  end

  def desired_scaling_parameters
    ret = {}
    ret[:desired_partition_count] = new_resource.partition_count if new_resource.partition_count
    ret[:desired_replication_count] = new_resource.replication_count if new_resource.replication_count
    ret[:desired_instance_type] =  new_resource.instance_type if new_resource.instance_type
    ret
  end

  #
  # API Update Functions
  #
  # The following functions all make changes to our domain.  Unlike
  # other AWS APIs we don't have a single modify function for this
  # domain.  Rather, updates our split up over a number of different
  # API requestsion.
  #
  def create_domain
    cs_client.create_domain(domain_name: new_resource.domain_name)[:domain_status]
  end

  def update_availability_options
    cs_client.update_availability_options(domain_name: new_resource.domain_name,
                                          multi_az: new_resource.multi_az)
  end

  def update_scaling_parameters
    cs_client.update_scaling_parameters(domain_name: new_resource.domain_name,
                                        scaling_parameters: desired_scaling_parameters)
  end

  def update_service_access_policy
    cs_client.update_service_access_policies(domain_name: new_resource.domain_name,
                                             access_policies: new_resource.access_policies)
  end

  def create_index_field(field)
    cs_client.define_index_field(domain_name: new_resource.domain_name, index_field: field)
  end

  #
  # API Query Functions
  #
  # The CloudSearch API doesn't provide all of the data about the
  # domain's settings via the descrbe instance API.  We have to call
  # additional endpoints to determine the current values of:
  # availability_options, scalability_parameters, index_fields, and
  # access_policies
  #
  def availability_options
    get_option(:availability_options)
  end

  def scaling_parameters(object)
    o = get_option(:scaling_parameters)
    o.merge(desired_instance_type: object[:search_instance_type])
  end

  def access_policies
    get_option(:service_access_policies, :access_policies)
  end

  def index_fields
    cs_client.describe_index_fields(domain_name: new_resource.name)[:index_fields]
  end

  def get_option(option_name, key=nil)
    opt = cs_client.send("describe_#{option_name}".to_sym,
                         {domain_name: new_resource.domain_name})[key || option_name]
    if ! opt[:status][:pending_deletion]
      opt[:options]
    else
      nil
    end
  end

  def cs_client
    @cs_client ||= new_resource.driver.cloudsearch(new_resource.cloudsearch_api_version)
  end
end

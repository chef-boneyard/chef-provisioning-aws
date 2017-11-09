require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsCloudsearchDomain < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_cloudsearch_domain

  def create_aws_object
    domain = nil # define here to ensure it is available outside of the coverge_by scope
    converge_by "create CloudSearch domain #{new_resource.name}" do
      domain = create_domain
    end

    update_aws_object(domain)

    # TODO: since we don't support updating index fields yet,
    # it will not be handled by update_aws_object, so we need to
    # create the index fields here.
    create_index_fields
  end

  def destroy_aws_object(domain)
    converge_by "delete CloudSearch domain #{new_resource.name}" do
      cs_client.delete_domain(domain_name: new_resource.name)
    end
    # CloudSearch can take over 30 minutes to delete so im not adding a waiter
    # for now
  end

  def update_aws_object(domain)
    if update_availability_options?(domain)
      converge_by "update availability options for CloudSearch domain #{new_resource}" do
        update_availability_options
      end
    end

    if update_scaling_params?(domain)
      converge_by "update scaling parameters for CloudSearch domain #{new_resource.name}" do
        update_scaling_parameters
      end
    end

    if update_policy?(domain)
      converge_by "update access policy for CloudSearch domain #{new_resource.name}" do
        update_service_access_policy
      end
    end

    if update_index_fields?(domain)
      Chef::Log.warn("Updating existing index_fields not currently supported")
    end
  end

  private

  def update_availability_options?(_domain)
    # new_resource.multi_az defaults to false so we don't need an existence check
    new_resource.multi_az != availability_options
  end

  def update_scaling_params?(domain)
    if new_resource.partition_count || new_resource.replication_count || new_resource.instance_type
      # We don't want to change scaling parameters that the user
      # didn't specify. Thus, we compare on a key-by-key basis.  Only
      # user-specified keys show up in desired_scaling_parameters
      actual_scaling_parameters = scaling_parameters(domain)
      desired_scaling_parameters.each do |key, value|
        return true if value != actual_scaling_parameters[key]
      end
      false
    else
      false
    end
  end

  def update_policy?(_domain)
    if !new_resource.access_policies.nil?
      new_resource.access_policies != access_policies
    else
      false
    end
  end

  def update_index_fields?(domain)
    if ! new_resource.index_fields.nil?
      index_fields.each do |index_field|
        if ! new_resource.index_fields.include?(index_field.to_h[:options])
          return true
        end
      end
      false
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
    cs_client.create_domain(domain_name: new_resource.name)[:domain_status]
  end

  def update_availability_options
    cs_client.update_availability_options(domain_name: new_resource.name,
                                          multi_az: new_resource.multi_az)
  end

  def update_scaling_parameters
    cs_client.update_scaling_parameters(domain_name: new_resource.name,
                                        scaling_parameters: desired_scaling_parameters)
  end

  def update_service_access_policy
    cs_client.update_service_access_policies(domain_name: new_resource.name,
                                             access_policies: new_resource.access_policies)
  end

  def create_index_field(field)
    cs_client.define_index_field(domain_name: new_resource.name, index_field: field)
  end

  def create_index_fields
    unless new_resource.index_fields.nil?
      new_resource.index_fields.each do |field|
        create_index_field(field)
      end
    end
  end

  #
  # API Query Functions
  #
  # The CloudSearch API doesn't provide all of the data about the
  # domain's settings via the descrbe domain API.  We have to call
  # additional endpoints to determine the current values of:
  # availability_options, scalability_parameters, index_fields, and
  # access_policies
  #
  def availability_options
    get_option(:availability_options)
  end

  def scaling_parameters(object)
    scaling_parameters = get_option(:scaling_parameters)
    scaling_parameters.desired_instance_type = object[:search_instance_type]
    scaling_parameters
  end

  def access_policies
    get_option(:service_access_policies, :access_policies)
  end

  def index_fields
    cs_client.describe_index_fields(domain_name: new_resource.name).index_fields
  end

  def get_option(option_name, key=nil)
    opt = cs_client.send("describe_#{option_name}".to_sym,
                         {domain_name: new_resource.name})[key || option_name]
    if ! opt[:status][:pending_deletion]
      opt[:options]
    else
      nil
    end
  end

  def cs_client
    @cs_client ||= new_resource.driver.cloudsearch
  end
end

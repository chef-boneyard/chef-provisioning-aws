require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/tagging_strategy/rds'

# inspiration taken from providers/aws_rds_subnet_group.rb
# but different enough that I'm not sure there is easy abstraction
class Chef::Provider::AwsRdsParameterGroup < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::RDSConvergeTags

  provides :aws_rds_parameter_group

  def create_aws_object
    converge_create_message = "create RDS parameter group #{new_resource.name} in #{region}"
    if update_parameters
      converge_notes = [converge_create_message, "  set group parameters to #{desired_options[:parameters]}"]
    else
      converge_notes = converge_create_message
    end

    converge_by converge_notes do
      driver.create_db_parameter_group(desired_create_options)

      if update_parameters
        driver.modify_db_parameter_group(desired_update_options)
      end
    end
  end

  def destroy_aws_object(_parameter_group)
    converge_by "delete RDS parameter group #{new_resource.name} in #{region}" do
      driver.delete_db_parameter_group(db_parameter_group_name: new_resource.name)
    end
  end

  def update_aws_object(_parameter_group)
    updates = required_updates
    if ! updates.empty?
      converge_by updates do
        driver.modify_db_parameter_group(desired_update_options)
      end
    end
  end

  def desired_create_options
    result = {}
    full_options = desired_options
    result[:db_parameter_group_name] = full_options[:db_parameter_group_name]
    result[:db_parameter_group_family] = full_options[:db_parameter_group_family]
    result[:description] = full_options[:description]
    result
  end

  def desired_update_options
    result = {}
    full_options = desired_options
    result[:db_parameter_group_name] = full_options[:db_parameter_group_name]
    result[:parameters] = full_options[:parameters]
    result
  end

  def desired_options
    @desired_options ||= begin
                           opts = {}
                           opts[:db_parameter_group_name] = new_resource.name
                           opts[:db_parameter_group_family] = new_resource.db_parameter_group_family
                           opts[:description] = new_resource.description
                           opts[:parameters] = new_resource.parameters
                           AWSResource.lookup_options(opts, resource: new_resource)
                         end
  end

  # Given an existing parameter group, return an array of update descriptions
  # representing the updates that need to be made.
  #
  # Also returns Chef warnings for all the fields required for create that
  # are not updateable, which is currently every field but parameters :(
  #
  # If no updates are needed, an empty array is returned.
  def required_updates
    # this is the only updateable field
    ret = []
    if update_parameters
      ret << "  set group parameters to #{desired_options[:parameters]}"
    end

    if ! desired_options[:db_parameter_group_family].nil?
      # modify_db_parameter_group doesn't support updating the db_parameter_group_family  according to
      # http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/RDS/Client.html#modify_db_parameter_group-instance_method
      # which is frustrating because it is required for create
      Chef::Log.warn "Updating description for RDS parameter groups is not supported by RDS client."
    end

    if ! desired_options[:description].nil?
      # modify_db_parameter_group doesn't support updating the description according to
      # http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/RDS/Client.html#modify_db_parameter_group-instance_method
      # which is frustrating because it is required for create
      Chef::Log.warn "Updating description for RDS parameter groups is not supported by RDS client."
    end

    if ! (desired_options[:aws_tags].nil? || desired_options[:aws_tags].empty?)
      # modify_db_parameter_group doesn't support the tags key according to
      # http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/RDS/Client.html#modify_db_parameter_group-instance_method
      Chef::Log.warn "Updating tags for RDS parameter groups is not supported by RDS client."
    end

    ret.unshift("update RDS parameter group #{new_resource.name} in #{region}") unless ret.empty?
    ret
  end

  private

  def update_parameters
    # We cannot properly check for idempotence here due to errors in the RDS API's describe_db_parameters endpoint
    # describe_db_parameters is supposed to return every field for every entry, but it does not return apply_method,
    # which is a required field to modify_db_parameter_group.
    #
    # Therefore, we cannot have idempotence on users updating the value of apply_method, so we must either
    # break in the case that the user specifies apply_method for a parameter and then later specified a different
    # value for apply_method for that parameter later in a recipe, or not be itempotent.
    #
    # Breaking the user is never the right option, so we have elected to not be itempotent.
    ! (desired_options[:parameters].nil? || desired_options[:parameters].empty?)
  end
  
  def driver
    new_resource.driver.rds
  end
end

require 'chef/provisioning/aws_driver/aws_rds_resource'
require 'chef/provisioning/aws_driver/aws_taggable'

class Chef::Resource::AwsRdsParameterGroup < Chef::Provisioning::AWSDriver::AWSRDSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  # there is no class for a parameter group specifically
  aws_sdk_type ::Aws::RDS

  attribute :name, kind_of: String, name_attribute: true
  attribute :db_parameter_group_family, kind_of: String, required: true
  attribute :description, kind_of: String, required: true
  attribute :parameters, kind_of: Array, default: []

  def aws_object
    object = driver.rds.describe_db_parameter_groups(db_parameter_group_name: name)[:db_parameter_groups].first

    # use paginated API to get all options
    initial_request = driver.rds.describe_db_parameters(db_parameter_group_name: name, max_records: 100)
    marker = initial_request[:marker]
    parameters = initial_request[:parameters]
    while !marker.nil?
      more_results = driver.rds.describe_db_parameters(db_parameter_group_name: name, max_records: 100, marker: marker)
      parameters += more_results[:parameters]
      marker = more_results[:marker]
    end
    driver.rds.reset_db_parameter_group(db_parameter_group_name: name, parameters: parameters)

    object
  rescue ::Aws::RDS::Errors::DBParameterGroupNotFound
    nil
  end

  def rds_tagging_type
    "pg"
  end
end

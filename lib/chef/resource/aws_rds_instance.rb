require 'chef/provisioning/aws_driver/aws_rds_resource'
require 'chef/provisioning/aws_driver/aws_taggable'

class Chef::Resource::AwsRdsInstance < Chef::Provisioning::AWSDriver::AWSRDSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::RDS::DBInstance, id: :db_instance_identifier

  attribute :db_instance_identifier, kind_of: String, name_attribute: true

  attribute :db_snapshot_identifier, kind_of: String
  attribute :engine, kind_of: String
  attribute :engine_version, kind_of: String
  attribute :db_instance_class, kind_of: String
  attribute :multi_az, default: false, kind_of: [TrueClass, FalseClass]
  attribute :allocated_storage, kind_of: Integer
  attribute :iops, kind_of: Integer
  attribute :publicly_accessible, kind_of: [TrueClass, FalseClass], default: false
  attribute :master_username, kind_of: String
  attribute :master_user_password, kind_of: String
  attribute :db_name, kind_of: String
  attribute :port, kind_of: Integer
  # We cannot pass the resource or an AWS object because there is no AWS model
  # and that causes lookup_options to fail
  attribute :db_subnet_group_name, kind_of: String
  # We cannot pass the resource or an AWS object because there is no AWS model
  # and that causes lookup_options to fail
  attribute :db_parameter_group_name, kind_of: String

  # RDS has a ton of options, allow users to set any of them via a
  # custom Hash
  attribute :additional_options, kind_of: Hash, default: {}

  def aws_object
    result = self.driver.rds_resource.db_instance(name)
    return nil unless result && result.db_instance_status != 'deleting'
    result
  rescue ::Aws::RDS::Errors::DBInstanceNotFound
    nil
  end

  def db_instance_status
    aws_object.db_instance_status if aws_object
  rescue ::Aws::RDS::Errors::DBInstanceNotFound
    nil
  end

  def rds_tagging_type
    "db"
  end
end

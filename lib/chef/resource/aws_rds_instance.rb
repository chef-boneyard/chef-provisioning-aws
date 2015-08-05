require 'chef/provisioning/aws_driver/aws_resource'


class Chef::Resource::AwsRdsInstance < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::RDS::DBInstance, id: :db_instance_identifier

  attribute :db_instance_identifier, kind_of: String, name_attribute: true

  attribute :engine, kind_of: String
  attribute :engine_version, kind_of: String
  attribute :db_instance_class, kind_of: String
  attribute :multi_az, default: false, kind_of: [TrueClass, FalseClass]
  attribute :allocated_storage, kind_of: Integer, default: 5
  attribute :iops, kind_of: Integer
  attribute :publicly_accessible, kind_of: [TrueClass, FalseClass], default: false
  attribute :master_username, kind_of: String
  attribute :master_user_password, kind_of: String
  attribute :db_name, kind_of: String
  attribute :db_port, kind_of: Integer

  attribute :aws_tags, kind_of: Hash

  # RDS has a ton of options, allow users to set any of them via a
  # custom Hash
  attribute :additional_options, kind_of: Hash, default: {}

  def aws_object
    res = driver.rds.instances[name]
    if res.exists? && ! ['deleted', 'deleting'].include?(res.status)
      res
    else
      nil
    end
  end
end

require 'chef/provisioning/aws_driver/aws_resource_with_entry'

class Chef::Resource::AwsRdsDbInstance < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::RDS::DBInstance, id: :db_instance_identifier, managed_entry_id_name: :db_instance_identifier
  
  actions :create, :nothing
  default_action :create

  attribute :db_instance_identifier, :kind_of => String, :name_attribute => true, aws_id_attribute: true
  attribute :engine, :kind_of => String
  attribute :db_instance_class, :kind_of => String
  attribute :master_username, :kind_of => String
  attribute :master_user_password, :kind_of => String
  attribute :allocated_storage
  attribute :db_subnet_group_name, :kind_of => String

  def aws_object
    driver, id = get_driver_and_id
    result = driver.rds.db_instances[db_instance_identifier] if db_instance_identifier

    if result.exists?
      result
    else
      nil
    end
  end

end

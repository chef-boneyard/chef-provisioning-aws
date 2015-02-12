require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsRdsDbInstance < Chef::Resource::AwsResource
  self.resource_name = 'aws_rds_db_instance'
  self.databag_name = 'aws_rds_db_instance'

  actions :create, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :engine, :kind_of => String
  attribute :db_instance_class, :kind_of => String
  attribute :master_username, :kind_of => String
  attribute :master_user_password, :kind_of => String
  attribute :allocated_storage

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

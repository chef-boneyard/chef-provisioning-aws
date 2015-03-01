require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsRdsDbSubnetGroup < Chef::Resource::AwsResource
  self.resource_name = 'aws_rds_db_subnet_group'
  self.databag_name = 'aws_rds_db_subnet_group'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :description, :kind_of => String
  attribute :subnets

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

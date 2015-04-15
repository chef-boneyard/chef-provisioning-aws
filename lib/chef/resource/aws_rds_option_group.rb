require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsRdsOptionGroup < Chef::Resource::AwsResource
  self.resource_name = 'aws_rds_option_group'
  self.databag_name = 'aws_rds_option_group'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :description, :kind_of => String
  attribute :engine_name, :kind_of => String
  attribute :major_engine_version, :kind_of => String
  attribute :options
  attribute :apply_immediately, :default => false

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

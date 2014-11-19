require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsSecurityGroup < Chef::Resource::AwsResource
  self.resource_name = 'aws_security_group'
  self.databag_name = 'aws_security_groups'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :vpc_id, :kind_of => String
  attribute :vpc_name, :kind_of => String
  attribute :inbound_rules
  attribute :outbound_rules
  stored_attribute :security_group_id
  stored_attribute :description

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

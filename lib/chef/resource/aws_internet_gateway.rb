require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsInternetGateway < Chef::Resource::AwsResource
  self.resource_name = 'aws_internet_gateway'
  self.databag_name = 'aws_internet_gateway'

  actions :create, :delete, :attach, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :vpc, :kind_of => String

  stored_attribute :internet_gateway_id

  attr_accessor :exists

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

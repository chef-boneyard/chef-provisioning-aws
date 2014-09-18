require 'chef/resource/aws_resource'
require 'chef_metal_aws'

class Chef::Resource::AwsSnsTopic < Chef::Resource::AwsResource
  self.resource_name = 'aws_sns_topic'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :topic_name, :kind_of => String

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

require 'chef/resource/aws_resource'
require 'chef_metal_aws'

class Chef::Resource::AwsSqsQueue < Chef::Resource::AwsResource
  self.resource_name = 'sqs_queue'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :queue_name, :kind_of => String

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

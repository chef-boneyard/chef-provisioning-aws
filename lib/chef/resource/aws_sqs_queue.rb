require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsSqsQueue < Chef::Resource::AwsResource
  self.resource_name = 'aws_sqs_queue'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :queue_name, String
  attribute :name, :kind_of => String, :name_attribute => true
  attribute :queue_name, :kind_of => String
  stored_attribute :created_at

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

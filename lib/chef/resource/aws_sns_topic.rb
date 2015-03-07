require 'chef/resource/aws_resource'

class Chef::Resource::AwsSnsTopic < Chef::Resource::AwsResource
  self.resource_name = 'aws_sns_topic'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true

  # Main code is in lib/chef/provisioning/aws_driver/managed_aws.rb
  def aws_object
    get_aws_object(:sns_topic, name)
  end
end

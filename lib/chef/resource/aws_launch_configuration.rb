require 'chef/resource/aws_resource'

class Chef::Resource::AwsLaunchConfiguration < Chef::Resource::AwsResource
  self.resource_name = 'aws_launch_configuration'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,          kind_of: String, name_attribute: true
  attribute :image,         kind_of: String
  attribute :instance_type, kind_of: String
  attribute :options,       kind_of: Hash,   default: {}

  # Main code is in lib/chef/provisioning/aws_driver/managed_aws.rb
  def aws_object
    get_aws_object(:launch_configuration, name)
  end
end

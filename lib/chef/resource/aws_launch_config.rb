require 'chef/resource/aws_resource'
require 'chef_metal_aws'

class Chef::Resource::AwsLaunchConfig < Chef::Resource::AwsResource
  self.resource_name = 'aws_launch_config'
  self.databag_name = 'launch_configs'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :image, :kind_of => String
  attribute :instance_type, :kind_of => String
end

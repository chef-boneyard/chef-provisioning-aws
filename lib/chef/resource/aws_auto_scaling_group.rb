require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsAutoScalingGroup < Chef::Resource::AwsResource
  self.resource_name = 'aws_auto_scaling_group'
  self.databag_name = 'auto_scaling_groups'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :desired_capacity, :kind_of => Integer
  attribute :launch_config, :kind_of => String
  attribute :min_size, :kind_of => Integer, :default => 1
  attribute :max_size, :kind_of => Integer, :default => 4
end

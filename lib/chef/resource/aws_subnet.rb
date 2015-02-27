require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsSubnet < Chef::Resource::AwsResource
  self.resource_name = 'aws_subnet'
  self.databag_name = 'aws_subnet'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :cidr_block, :kind_of => String
  attribute :vpc, :kind_of => String
  attribute :availability_zone, :kind_of => String
  attribute :map_public_ip_on_launch, :kind_of => [ TrueClass, FalseClass ]

  stored_attribute :subnet_id
end

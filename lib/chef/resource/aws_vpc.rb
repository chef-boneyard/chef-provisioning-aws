require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsVpc < Chef::Resource::AwsResource
  self.resource_name = 'aws_vpc'
  self.databag_name = 'aws_vpc'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :cidr_block, :kind_of => String
  attribute :internet_gateway, :kind_of => [ String, TrueClass, FalseClass ]
  attribute :internet_gateway_routes, :kind_of => Array
  def internet_gateway_routes(*routes)
    if routes.size == 0
      @internet_gateway_routes || []
    else
      @internet_gateway_routes = routes.flatten
    end
  end

  stored_attribute :vpc_id

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

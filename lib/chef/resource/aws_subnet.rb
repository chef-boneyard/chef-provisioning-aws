require 'chef/resource/aws_resource'

class Chef::Resource::AwsSubnet < Chef::Resource::AwsResource
  self.resource_name = 'aws_subnet'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,              kind_of: String, name_attribute: true
  attribute :cidr_block,        kind_of: String
  attribute :vpc,               kind_of: String
  attribute :availability_zone, kind_of: String
  attribute :map_public_ip_on_launch, kind_of: [ TrueClass, FalseClass ]

  def aws_object
    get_aws_object(:subnet, name)
  end

  # Include this if your resource saves data about the AWS object in Chef (only
  # if you need to look up IDs).
  def managed_entry_id
    [ self.class.resource_name.to_sym, name ]
  end
end

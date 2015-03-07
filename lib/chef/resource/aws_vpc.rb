require 'chef/resource/aws_resource'

class Chef::Resource::AwsVpc < Chef::Resource::AwsResource
  self.resource_name = 'aws_vpc'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,             kind_of: String, name_attribute: true
  attribute :cidr_block,       kind_of: String
  attribute :instance_tenancy, equal_to: [ :default, :dedicated ], default: :default

  def aws_object
    get_aws_object(:vpc, name)
  end

  # Include this if your resource saves data about the AWS object in Chef (only
  # if you need to look up IDs).
  def managed_entry_id
    [ self.class.resource_name.to_sym, name ]
  end
end

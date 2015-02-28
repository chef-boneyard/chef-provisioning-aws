require 'chef/resource/aws_resource'

class Chef::Resource::AwsVpc < Chef::Resource::AwsResource
  self.resource_name = 'aws_vpc'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,             kind_of: String, name_attribute: true
  attribute :cidr_block,       kind_of: String
  attribute :instance_tenancy, equal_to: [ :default, :dedicated ], default: :default

  # Main code is in lib/chef/provisioning/aws_driver/managed_aws.rb
  def aws_object
    get_aws_object(:vpc, name)
  end
end

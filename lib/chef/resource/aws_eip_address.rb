require 'chef/resource/aws_resource'
require 'ipaddr'

class Chef::Resource::AwsEipAddress < Chef::Resource::AwsResource
  self.resource_name = 'aws_eip_address'

  actions :delete, :nothing, :associate, :disassociate
  default_action :associate

  attribute :name, kind_of: String, name_attribute: true

  attribute :associate_to_vpc, kind_of: [TrueClass, FalseClass], default: false
  attribute :machine,          kind_of: String

  # Main code is in lib/chef/provisioning/aws_driver/managed_aws.rb
  def aws_object
    get_aws_object(:eip_address, name)
  end

  Chef::Provisioning::ChefManagedEntryStore.type_names_for_backcompat[:aws_eip_address] = 'eip_addresses'
end

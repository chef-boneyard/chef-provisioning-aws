require 'chef/resource/aws_resource'

class Chef::Resource::AwsEbsVolume < Chef::Resource::AwsResource
  self.resource_name = 'aws_ebs_volume'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,    kind_of: String, name_attribute: true

  attribute :availability_zone, kind_of: String
  attribute :size,              kind_of: Integer
  attribute :snapshot,          kind_of: String

  attribute :iops,              kind_of: Integer
  attribute :volume_type,       kind_of: Symbol
  attribute :encrypted,         kind_of: [ TrueClass, FalseClass ]

  # Main code is in lib/chef/provisioning/aws_driver/managed_aws.rb
  def aws_object
    get_aws_object(:volume, name)
  end

  Chef::Provisioning::ChefManagedEntryStore.type_names_for_backcompat[:aws_ebs_volume] = 'ebs_volumes'
end

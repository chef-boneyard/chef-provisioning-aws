require 'chef/resource/aws_resource'

class Chef::Resource::AwsSecurityGroup < Chef::Resource::AwsResource
  self.resource_name = 'aws_security_group'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,          kind_of: String, name_attribute: true
  attribute :vpc,           kind_of: String
  attribute :description,   kind_of: String
  attribute :inbound_rules
  attribute :outbound_rules

  # Main code is in lib/chef/provisioning/aws_driver/managed_aws.rb
  def aws_object
    get_aws_object(:security_group, name)
  end

  # Include this if your resource saves data about the AWS object in Chef (only
  # if you need to look up IDs).
  def managed_entry_id
    [ self.class.resource_name.to_sym, name ]
  end

end

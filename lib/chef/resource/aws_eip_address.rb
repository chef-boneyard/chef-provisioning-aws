require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'
require 'chef/provisioning/machine_spec'

class Chef::Resource::AwsEipAddress < Chef::Resource::AwsResource
  self.resource_name = 'aws_eip_address'
  self.databag_name = 'eip_addresses'

  actions :create, :delete, :nothing, :associate, :release
  default_action :associate

  stored_attribute :public_ip
  stored_attribute :domain
  stored_attribute :instance_id

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :associate_to_vpc, :kind_of => [TrueClass, FalseClass], :default => false
  attribute :machine, :kind_of => String

  def initialize(*args)
    super
  end

  def after_created
    super
  end


end

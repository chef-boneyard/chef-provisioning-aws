require 'chef/resource/lwrp_base'
require 'chef/provisioning/chef_managed_entry_store'
require 'chef/provisioning/aws_driver/managed_aws'

# Common AWS resource - contains metadata that all AWS resources will need
class Chef::Resource::AwsResource < Chef::Resource::LWRPBase
  attribute :driver
  attribute :chef_server

  def initialize(*args)
    super
    @driver = run_context.chef_provisioning.current_driver
    @chef_server = run_context.cheffish.current_chef_server
  end

  #
  # Get the AWS driver
  #
  def aws_driver
    run_context.chef_provisioning.driver_for(driver)
  end

  #
  # Get the managed entry store where ids are stored
  #
  def managed_entries
    Chef::Provisioning::ChefManagedEntryStore.new(chef_server)
  end

  #
  # Get the AWS object represented by this resource.
  #
  # @return The AWS object, or `nil` if it does not exist.
  #
  def aws_object
    raise NotImplementedError, :aws_object
  end

  #
  # Get the requested AWS object.
  #
  # @param type The type of AWS object to get.
  # @param id The ID of the object.
  #
  def get_aws_object(type, id)
    Chef::Provisioning::AWSDriver::ManagedAWS.new(managed_entries, aws_driver).get_aws_object(type, id)
  end
end

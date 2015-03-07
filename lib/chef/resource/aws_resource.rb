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
  # Get the managed entry store where ids are stored
  #
  def managed_entries
    Chef::Provisioning::ChefManagedEntryStore.new(chef_server)
  end

  #
  # Get the managed entry for this particular object (if there is one)
  #
  def managed_entry
    type, id = managed_entry_id
    if type && id
      managed_entries.get(type, id)
    else
      nil
    end
  end

  #
  # Get the AWS driver
  #
  def aws_driver
    entry = managed_entry
    run_context.chef_provisioning.driver_for(entry ? entry.driver_url : driver)
  end

  #
  # Get the ManagedAWS object for this resource
  #
  def managed_aws
    Chef::Provisioning::AWSDriver::ManagedAWS.new(managed_entries, aws_driver)
  end

  #
  # Get the requested AWS object.
  #
  # @param type The type of AWS object to get.
  # @param id The ID of the object.
  #
  def get_aws_object(type, id)
    managed_aws.get_aws_object(type, id)
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
  # Get the managed entry type and id for this object
  #
  # Returns `nil` if this object does not save itself back to Chef
  #
  def managed_entry_id
    nil
  end
end

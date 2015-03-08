require 'chef/provider/lwrp_base'
require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/provisioning/chef_managed_entry_store'
require 'chef/provisioning/chef_provider_action_handler'
require 'chef/provisioning/aws_driver/managed_aws'

class Chef::Provider::AwsProvider < Chef::Provider::LWRPBase
  use_inline_resources

  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  # All these need to implement whyrun
  def whyrun_supported?
    true
  end

  def managed_entries
    @managed_entries ||= new_resource.managed_entries
  end

  def managed_entry
    # If we don't find the managed entry the first time, don't keep looking for it.
    @managed_entry = new_resource.managed_entry if !defined?(@managed_entry)
    @managed_entry
  end

  def save_managed_entry(reference)
    type, id = new_resource.managed_entry_id
    @managed_entry = managed_entries.new_entry(type, id)
    managed_entry.reference = reference
    managed_entry.driver_url = aws_driver.driver_url
    managed_entry.save(action_handler)
  end

  def delete_managed_entry
    type, id = new_resource.managed_entry_id
    managed_entries.delete(type, id, action_handler)
    @managed_entry = nil
  end

  def aws_driver
    @aws_driver ||= begin
      entry = managed_entry
      run_context.chef_provisioning.driver_for(entry ? entry.driver_url : driver)
    end
  end

  def managed_aws
    @managed_aws ||= Chef::Provisioning::AWSDriver::ManagedAWS.new(managed_entries, aws_driver)
  end

  def region
    aws_driver.aws_config.region
  end

  def aws_object
    @aws_object = new_resource.aws_object if !defined?(@aws_object)
    @aws_object
  end
end

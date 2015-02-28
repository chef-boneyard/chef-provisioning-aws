require 'chef/provider/lwrp_base'
require 'chef/resource/aws_resource'
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

  def entry_id
    new_resource.name
  end

  def new_driver
    run_context.chef_provisioning.driver_for(new_resource.driver)
  end

  def current_driver
    run_context.chef_provisioning.driver_for(entry.driver_url)
  end

  def managed_aws
    @managed_aws ||= Chef::Provisioning::AWSDriver::ManagedAWS.new(managed_entries, aws_driver)
  end

  def managed_entries
    new_resource.managed_entries
  end

  def entry
    @entry ||= managed_entries.get(new_resource.class.resource_name, entry_id)
  end

  def save_entry(reference)
    entry = managed_entries.new_entry(new_resource.class.resource_name, entry_id)
    entry.reference = reference
    entry.driver_url = new_driver.driver_url
    entry.save(action_handler)
  end

  def delete_entry
    managed_entries.delete(new_resource.class.resource_name, entry_id, action_handler)
  end

  def region
    new_driver.aws_config.region
  end

  def aws_driver
    current_aws_object ? current_driver : new_driver
  end

  def current_aws_object
    @current_aws_object = new_resource.aws_object if !defined?(@current_aws_object)
    @current_aws_object
  end
end

require 'chef/provider/lwrp_base'
require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/provisioning/chef_managed_entry_store'
require 'chef/provisioning/chef_provider_action_handler'

module Chef::Provisioning::AWSDriver
class AWSProvider < Chef::Provider::LWRPBase
  use_inline_resources

  AWSResource = Chef::Provisioning::AWSDriver::AWSResource

  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  # All these need to implement whyrun
  def whyrun_supported?
    true
  end

  def region
    new_resource.driver.aws_config.region
  end

  def driver
    new_resource.driver
  end
end
end

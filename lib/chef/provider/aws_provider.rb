require 'chef/provider/lwrp_base'

class Chef::Provider::AwsProvider < Chef::Provider::LWRPBase
  use_inline_resources

  # All these need to implement whyrun
  def whyrun_supported?
    true
  end

  def fqn
    if id
      id
    else
      "#{new_resource.name}_#{new_driver.aws_config.region}"
    end
  end

  def new_driver
    run_context.chef_provisioning.driver_for(new_resource.driver)
  end
end

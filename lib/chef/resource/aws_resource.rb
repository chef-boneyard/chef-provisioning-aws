# Common AWS resource - contains metadata that all AWS resources will need
class Chef::Resource::AwsResource < Chef::Resource::ChefDataBagResource
  stored_attribute :driver

  def initialize(*args)
    super
    @driver = run_context.chef_provisioning.current_driver
  end

end

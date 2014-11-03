# Common AWS resource - contains metadata that all AWS resources will need
class Chef::Resource::AwsResource < Chef::Resource::ChefDataBagResource
  stored_attribute :region_name

  def initialize(*args)
    super
    @region_name = run_context.chef_provisioning.current_data_center
  end

end

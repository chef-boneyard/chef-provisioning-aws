require 'chef/resource/chef_data_bag_resource'

# Common AWS resource - contains metadata that all AWS resources will need
class Chef::Resource::AwsResource < Chef::Resource::ChefDataBagResource
  stored_attribute :region_name

  def initialize(*args)
    super
    @region_name = run_context.chef_metal.current_datacenter
  end

end
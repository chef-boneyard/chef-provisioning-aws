require 'chef/provider/lwrp_base'
require 'chef_metal_aws/credentials'

class Chef::Provider::AwsProvider < Chef::Provider::LWRPBase

  attr_reader :credentials

  def initialize(*args)
    super
    # TODO - temporary
    @credentials = ChefMetalAWS::Credentials.new
    @credentials.load_default
  end
end
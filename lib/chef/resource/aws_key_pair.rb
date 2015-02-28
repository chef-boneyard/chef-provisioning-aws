require 'chef/provisioning'

class Chef::Resource::AwsKeyPair < Chef::Resource::AwsResource
  self.resource_name = 'aws_key_pair'

  actions :create, :delete, :nothing
  default_action :create

  # Private key to use as input (will be generated if it does not exist)
  attribute :private_key_path, :kind_of => String
  # Public key to use as input (will be generated if it does not exist)
  attribute :public_key_path, :kind_of => String
  # List of parameters to the private_key resource used for generation of the key
  attribute :private_key_options, :kind_of => Hash

  # TODO what is the right default for this?
  attribute :allow_overwrite, :kind_of => [TrueClass, FalseClass], :default => false

  # Main code is in lib/chef/provisioning/aws_driver/managed_aws.rb
  def aws_object
    get_aws_object(:key_pair, name)
  end
end

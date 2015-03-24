require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsKeyPair < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::EC2::KeyPair, id: :name

  # Private key to use as input (will be generated if it does not exist)
  attribute :private_key_path, :kind_of => String
  # Public key to use as input (will be generated if it does not exist)
  attribute :public_key_path, :kind_of => String
  # List of parameters to the private_key resource used for generation of the key
  attribute :private_key_options, :kind_of => Hash

  # TODO what is the right default for this?
  attribute :allow_overwrite, :kind_of => [TrueClass, FalseClass], :default => false

  def aws_object
    result = driver.ec2.key_pairs[name]
    result && result.exists? ? result : nil
  end
end

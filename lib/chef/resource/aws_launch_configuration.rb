require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsLaunchConfiguration < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::EC2::LaunchConfiguration, id: :name

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,          kind_of: String, name_attribute: true
  attribute :image,         kind_of: String
  attribute :instance_type, kind_of: String
  attribute :options,       kind_of: Hash,   default: {}

  def aws_object
    driver.ec2.launch_configurations[name]
  end
end

require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsLaunchConfiguration < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::AutoScaling::LaunchConfiguration, id: :name

  attribute :name,          kind_of: String, name_attribute: true
  attribute :image,         kind_of: [ String, AWS::EC2::Image, ::Aws::EC2::Image ]
  attribute :instance_type, kind_of: String
  attribute :options,       kind_of: Hash,   default: {}

  def aws_object
    result = driver.auto_scaling.launch_configurations[name]
    result && result.exists? ? result : nil
  end
end

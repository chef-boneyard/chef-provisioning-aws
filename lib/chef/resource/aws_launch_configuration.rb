require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsLaunchConfiguration < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type ::Aws::AutoScaling::LaunchConfiguration, id: :name

  attribute :name,          kind_of: String, name_attribute: true
  attribute :image,         kind_of: [ String, ::Aws::EC2::Image, ::Aws::EC2::Image ]
  attribute :instance_type, kind_of: String
  attribute :options,       kind_of: Hash,   default: {}

  def aws_object
    launchconfig = ::Aws::AutoScaling::LaunchConfiguration.new(name,{client: driver.auto_scaling_client} )
    result = launchconfig.data
    result
  end
end

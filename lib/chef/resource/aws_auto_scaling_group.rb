require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsAutoScalingGroup < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::AutoScaling::Group, id: :name

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,                 kind_of: String,  name_attribute: true
  attribute :options,              kind_of: Hash,    default: {}
  attribute :desired_capacity,     kind_of: Integer
  attribute :launch_configuration, kind_of: String
  attribute :min_size,             kind_of: Integer, default: 1
  attribute :max_size,             kind_of: Integer, default: 4
  attribute :load_balancers,       kind_of: Array

  def aws_object
    driver.auto_scaling.groups[name]
  end
end

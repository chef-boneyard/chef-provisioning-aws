require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsAutoScalingGroup < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::AutoScaling::AutoScalingGroup

  attribute :name,                        kind_of: String,  name_attribute: true
  attribute :options,                     kind_of: Hash,    default: {}
  attribute :availability_zones,          kind_of: Array
  attribute :desired_capacity,            kind_of: Integer
  attribute :launch_configuration,        kind_of: String
  attribute :min_size,                    kind_of: Integer
  attribute :max_size,                    kind_of: Integer
  attribute :load_balancers,              kind_of: Array,   coerce: proc { |value| [value].flatten }
  attribute :notification_configurations, kind_of: Array,   default: []
  attribute :scaling_policies,            kind_of: Hash,    default: {}

  def aws_object
    result = driver.auto_scaling_resource.group(name)
    result && result.exists? ? result : nil
  end
end

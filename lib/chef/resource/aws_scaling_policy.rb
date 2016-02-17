require 'chef/provisioning/aws_driver/aws_resource'

# AWS Scaling Policy Resource
class Chef::Resource::AwsScalingPolicy < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::AutoScaling::ScalingPolicy

  attribute :name,                kind_of: String,  name_attribute: true
  attribute :auto_scaling_group,  kind_of: String,  required: true
  attribute :adjustment_type,     kind_of: String,  required: true
  attribute :scaling_adjustment,  kind_of: Integer, required: true
  attribute :cooldown,            kind_of: Integer, default: nil
  attribute :min_adjustment_step, kind_of: Integer, default: nil

  def aws_object
    group = driver.auto_scaling.groups[auto_scaling_group]
    return nil unless group && group.exists?

    policy = group.scaling_policies[name]
    policy && policy.exists? ? policy : nil
  end
end

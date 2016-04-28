require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsCloudwatchAlarm < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type AWS::CloudWatch::Alarm, id: :name

  property :name, String, name_attribute: true
  property :namespace, String, required: true
  property :metric_name, String, required: true
  property :dimensions, Array
  property :comparison_operator, String, required: true
  property :evaluation_periods, Integer, required: true
  property :period, Integer, required: true
  property :statistic, String, required: true
  property :threshold, Integer, required: true
  property :insufficient_data_actions, Array
  property :ok_actions, Array
  property :actions_enabled, [TrueClass, FalseClass]
  property :alarm_actions, Array
  property :alarm_description, String
  property :unit, String

  def aws_object
    result = driver.cloudwatch.alarms[name]
    result && result.exists? ? result : nil
  end
end

require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsCloudwatchAlarm < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type AWS::CloudWatch::Alarm, id: :name

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :namespace, :kind_of => String, :required => true
  attribute :metric_name, :kind_of => String, :required => true
  attribute :dimensions, :kind_of => Array, :default => []
  attribute :comparison_operator, :kind_of => String, :required => true
  attribute :evaluation_periods, :kind_of => Integer, :required => true
  attribute :period, :kind_of => Integer, :required => true
  attribute :statistic, :kind_of => String, :required => true
  attribute :threshold, :kind_of => Integer, :required => true
  attribute :insufficient_data_actions, :kind_of => Array, :default => []
  attribute :ok_actions, :kind_of => Array, :default => []
  attribute :actions_enabled, :kind_of => [TrueClass, FalseClass], :default => false
  attribute :alarm_actions, :kind_of => Array, :default => []
  attribute :alarm_description, :kind_of => String, :default => nil
  attribute :unit, :kind_of => String, :default => nil

  def aws_object
    result = driver.cloudwatch.alarms[name]
    result && result.exists? ? result : nil
  end
end

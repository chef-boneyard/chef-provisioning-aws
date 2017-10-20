require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsCloudwatchAlarm < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::CloudWatch::Alarm, id: :name

  # This name must be unique within the user's AWS account
  attribute :name, :kind_of => String, :name_attribute => true
  attribute :namespace, :kind_of => String
  attribute :metric_name, :kind_of => String
  attribute :dimensions, :kind_of => Array
  attribute :comparison_operator, :kind_of => String
  attribute :evaluation_periods, :kind_of => Integer
  attribute :period, :kind_of => [Integer,Float], coerce: proc {|v| v.to_f}
  attribute :statistic, :kind_of => String
  attribute :threshold, :kind_of => [Integer,Float]
  attribute :insufficient_data_actions, :kind_of => Array, coerce: proc {|v| [v].flatten}
  attribute :ok_actions, :kind_of => Array, coerce: proc {|v| [v].flatten}
  attribute :alarm_actions, :kind_of => Array, coerce: proc {|v| [v].flatten}
  attribute :actions_enabled, :kind_of => [TrueClass, FalseClass]
  attribute :alarm_description, :kind_of => String
  attribute :unit, :kind_of => String

  def aws_object
    # TODO exists? isn't defined yet
    # https://github.com/aws/aws-sdk-ruby/issues/1171
    a = driver.cloudwatch_resource.alarm(name)
    return nil if a.data.nil?
    a
  rescue ::Aws::CloudWatch::Errors::NoSuchEntity
    nil
  end

end

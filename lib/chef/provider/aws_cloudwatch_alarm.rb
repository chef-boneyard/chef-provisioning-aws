require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsCloudwatchAlarm < Chef::Provisioning::AWSDriver::AWSProvider

  provides :aws_cloudwatch_alarm

  REQUIRED_OPTS = %i(namespace metric_name comparison_operator
                     evaluation_periods period statistic threshold)

  OTHER_OPTS = %i(dimensions insufficient_data_actions ok_actions
                  actions_enabled alarm_actions alarm_description unit)

  COMPARISON_VALUES = %w(GreaterThanOrEqualToThreshold GreaterThanThreshold
                         LessThanThreshold LessThanOrEqualToThreshold)

  STATISTIC_VALUES = %w(SampleCount Average Sum Minimum Maximum)

  def update_aws_object(instance)
    Chef::Log.warn("aws_cloudwatch_alarm does not support modifying an alarm")
  end

  def create_aws_object
    validate_comparison(new_resource.comparison_operator)
    validate_statistic(new_resource.statistic)

    converge_by "creating cloudwatch alarm #{new_resource.name} in #{region}" do
      new_resource.driver.cloudwatch.alarms.create(new_resource.name,
                                                   options_hash)
    end
  end

  def destroy_aws_object(instance)
    converge_by "destroying cloudwatch alarm #{new_resource.name} in #{region}" do
      new_resource.driver.cloudwatch.alarms.delete(new_resource.name)
    end
  end

  def value_set(value)
    return false if value.nil?
    return true if value.is_a?(TrueClass) || value.is_a?(FalseClass)
    return !value.empty?
  end

  def options_hash
    @options_hash ||= begin
      opts = {}
      REQUIRED_OPTS.each do |opt|
        opts[opt] = new_resource.send(opt)
      end
      OTHER_OPTS.each do |opt|
        opts[opt] = new_resource.send(opt) if value_set(new_resource.send(opt))
      end
      AWSResource.lookup_options(opts, resource: new_resource)
      opts
    end
  end

  def validate_comparison(operator)
    Chef::Log.fail("Invalid value #{operator} for comparison operator, valid
                    values include: #{COMPARISON_VALUES}.") \
      unless COMPARISON_VALUES.include? operator
  end

  def validate_statistic(statistic)
    Chef::Log.fail("Invalid value #{statistic} for statistic, valid
                    values include: #{STATISTIC_VALUES}") \
      unless STATISTIC_VALUES.include? statistic
  end
end

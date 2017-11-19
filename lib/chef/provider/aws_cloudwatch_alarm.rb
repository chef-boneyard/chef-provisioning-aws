require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsCloudwatchAlarm < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_cloudwatch_alarm

  def create_aws_object
    converge_by "creating cloudwatch alarm #{new_resource.name} in #{region}" do
      new_resource.driver.cloudwatch_client.put_metric_alarm(desired_options)
    end
  end

  def update_aws_object(alarm)
    if update_required?(alarm)
      converge_by "updating cloudwatch alarm #{new_resource.name} in #{region}" do
        new_resource.driver.cloudwatch_client.put_metric_alarm(desired_options)
      end
    end
  end

  def destroy_aws_object(alarm)
    converge_by "destroying cloudwatch alarm #{new_resource.name} in #{region}" do
      alarm.delete
    end
  end

  def desired_options
    @desired_options ||= begin
      # Because an update is a PUT, we must ensure that any properties not specified
      # on the resource that are already present on the object stay the same
      aws_object = new_resource.aws_object
      opts = {alarm_name: new_resource.name}
      %i(namespace metric_name comparison_operator
         evaluation_periods period statistic threshold
         actions_enabled alarm_description unit).each do |opt|
        if !new_resource.public_send(opt).nil?
          opts[opt] = new_resource.public_send(opt)
        elsif aws_object && !aws_object.public_send(opt).nil?
          opts[opt] = aws_object.public_send(opt)
        end
      end
      if !new_resource.dimensions.nil?
        opts[:dimensions] = new_resource.dimensions
      elsif aws_object && !aws_object.dimensions.nil?
        opts[:dimensions] = aws_object.dimensions.map! {|d| d.to_h}
      end
      # Normally we would just use `lookup_options` here but because these parameters
      # don't necessarily sound like sns topics we manually do it
      %i{insufficient_data_actions ok_actions alarm_actions}.each do |opt|
        if !new_resource.public_send(opt).nil?
          opts[opt] = new_resource.public_send(opt)
          opts[opt].map! do |action|
            if action.kind_of?(String) && !(action =~ /^arn:/)
              aws_object = Chef::Resource::AwsSnsTopic.get_aws_object(action, resource: new_resource)
              action = aws_object.attributes["TopicArn"] if aws_object
            end
            action
          end
        elsif aws_object && !aws_object.public_send(opt).nil?
          opts[opt] = aws_object.public_send(opt)
        end
      end
      opts
    end
  end

  def update_required?(alarm)
    %i{namespace metric_name comparison_operator
       evaluation_periods period statistic threshold
       actions_enabled alarm_description unit}.each do |opt|
      if alarm.public_send(opt) != desired_options[opt]
        return true
      end
    end
    unless (Set.new(alarm.dimensions.map {|d| d.to_h}) ^ Set.new(desired_options[:dimensions])).empty?
      return true
    end
    %i(insufficient_data_actions ok_actions alarm_actions).each do |opt|
      unless (Set.new(alarm.public_send(opt)) ^ Set.new(desired_options[opt])).empty?
        return true
      end
    end
    return false
  end
end

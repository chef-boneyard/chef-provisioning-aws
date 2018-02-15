require 'chef/provisioning/aws_driver/aws_provider'
require 'set'
require 'chef/provisioning/aws_driver/tagging_strategy/auto_scaling'

class Chef::Provider::AwsAutoScalingGroup < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::AutoScalingConvergeTags

  provides :aws_auto_scaling_group

  protected

  def create_aws_object
    converge_by "create Auto Scaling group #{new_resource.name} in #{region}" do
      options = desired_options.dup
      options[:min_size] ||= 1
      options[:max_size] ||= 1
      options[:auto_scaling_group_name] = new_resource.name
      options[:launch_configuration_name] = new_resource.launch_configuration if new_resource.launch_configuration
      options[:load_balancer_names] = new_resource.load_balancers if new_resource.load_balancers
      options[:vpc_zone_identifier] = [options.delete(:subnets)].flatten.join(",") if options[:subnets]

      aws_obj = new_resource.driver.auto_scaling_resource.create_group(options)

      new_resource.scaling_policies.each do |policy_name, policy|
        aws_obj.put_scaling_policy(policy_name: policy_name, adjustment_type: policy[:adjustment_type], scaling_adjustment: policy[:scaling_adjustment])
      end

      new_resource.notification_configurations.each do |config|
        aws_obj.client.put_notification_configuration(auto_scaling_group_name: aws_obj.name, topic_arn: config[:topic], notification_types: config[:types])
      end

      aws_obj
    end
  end

  def update_aws_object(group)
    # TODO add updates for group
  end

  def destroy_aws_object(group)
    converge_by "delete Auto Scaling group #{new_resource.name} in #{region}" do
      group.delete(force_delete: true)
      group.wait_until_not_exists
    end
  end

  def desired_options
    @desired_options ||= begin
      options = new_resource.options.dup
      %w( min_size max_size availability_zones desired_capacity ).each do |var|
        var = var.to_sym
        value = new_resource.public_send(var)
        options[var] = value if value
      end
      AWSResource.lookup_options(options, resource: new_resource)
    end
  end

end

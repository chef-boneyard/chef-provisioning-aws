require 'chef/provisioning/aws_driver/aws_provider'

# AWS Scaling Policy Provider
class Chef::Provider::AwsScalingPolicy < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_scaling_policy

  protected

  def create_aws_object
    group = new_resource.driver.auto_scaling.groups[
      new_resource.auto_scaling_group]

    fail "Auto scaling group #{new_resource.auto_scaling_group}" \
      ' does not exist' unless group.exists?

    update_scaling_policy(group)
  end

  def update_aws_object(policy)
    fail 'Scaling group cannot be changed on a scaling policy' \
      unless policy.group.name == new_resource.auto_scaling_group

    # Check options against the current policy

    matched = true
    %w(adjustment_type scaling_adjustment min_adjustment_step
       cooldown).each do |option|
      if new_resource.send(option) != policy.send(option)
        matched = false
        break
      end
    end

    update_scaling_policy(policy.group) unless matched
  end

  def delete_aws_object(policy)
    converge_by "delete scaling policy #{new_resource.name} in #{region}" do
      policy.delete!
    end
  end

  private

  def update_scaling_policy(group)
    options = {
      adjustment_type: new_resource.adjustment_type,
      scaling_adjustment: new_resource.scaling_adjustment
    }

    options[:min_adjustment_step] =
      new_resource.min_adjustment_step unless \
      new_resource.min_adjustment_step.nil?

    options[:cooldown] =
      new_resource.cooldown unless new_resource.cooldown.nil?

    converge_by "update scaling policy #{new_resource.name} in #{region}" do
      group.scaling_policies.put(new_resource.name, options)
    end
  end
end

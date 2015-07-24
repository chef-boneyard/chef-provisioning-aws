require 'chef/provisioning/aws_driver/aws_provider'
require 'set'

class Chef::Provider::AwsAutoScalingGroup < Chef::Provisioning::AWSDriver::AWSProvider

  protected

  def create_aws_object
    converge_by "create new Auto Scaling Group #{new_resource.name} in #{region}" do
      options = desired_options.dup
      options[:min_size] ||= 1
      options[:max_size] ||= 1

      new_resource.driver.auto_scaling.groups.create( new_resource.name, options )
    end
  end

  def update_aws_object(group)
    # TODO add updates for group
  end

  def destroy_aws_object(group)
    converge_by "delete Auto Scaling Group #{new_resource.name} in #{region}" do
      group.delete!
    end
  end

  def desired_options
    @desired_options ||= begin
      options = new_resource.options
      %w(launch_configuration min_size max_size availability_zones desired_capacity load_balancers).each do |var|
        var = var.to_sym
        value = new_resource.public_send(var)
        options[var] = value if value
      end
      AWSResource.lookup_options(options, resource: new_resource)
    end
  end

end

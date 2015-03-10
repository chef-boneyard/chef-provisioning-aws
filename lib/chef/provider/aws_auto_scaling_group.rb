require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsAutoScalingGroup < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    aws_object = new_resource.aws_object
    if aws_object.nil?
      auto_scaling_opts = new_resource.options
      %w(launch_configuration min_size max_size availability_zones desired_capacity load_balancers).each do |var|
        var = var.to_sym
        value = new_resource.public_send(var)
        auto_scaling_opts[var] = value if value
      end
      auto_scaling_opts[:min_size] ||= 1
      auto_scaling_opts[:max_size] ||= 1
      auto_scaling_opts = AWSResource.lookup_options(auto_scaling_opts, resource: new_resource)

      converge_by "Creating new Auto Scaling group #{new_resource.name} in #{region}" do
        driver.auto_scaling.groups.create(
          new_resource.name,
          auto_scaling_opts
        )
      end
    end
  end

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      converge_by "Deleting Auto Scaling group #{new_resource.name} in #{region}" do
        aws_object.delete!
      end
    end
  end

end

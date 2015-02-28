require 'chef/provider/aws_provider'

class Chef::Provider::AwsAutoScalingGroup < Chef::Provider::AwsProvider

  action :create do
    if current_aws_object.nil?
      auto_scaling_opts = new_resource.options
      %w(launch_configuration min_size max_size availability_zones desired_capacity load_balancers).each do |var|
        var = var.to_sym
        value = new_resource.public_send(var)
        auto_scaling_opts[var] = value if value
      end
      auto_scaling_opts = managed_aws.lookup_options(auto_scaling_opts)

      converge_by "Creating new Auto Scaling group #{new_resource.name} in #{region}" do
        new_driver.auto_scaling.groups.create(
          new_resource.name,
          auto_scaling_opts
        )
      end
    end
  end

  action :delete do
    if current_aws_object
      converge_by "Deleting Auto Scaling group #{new_resource.name} in #{region}" do
        current_aws_object.delete!
      end
    end
  end

end

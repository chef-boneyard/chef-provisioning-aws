require 'chef/provider/aws_provider'

class Chef::Provider::AwsAutoScalingGroup < Chef::Provider::AwsProvider
  action :create do
    if existing_group.nil?
      auto_scaling_opts = {
        :launch_configuration => new_resource.launch_config,
        :min_size => new_resource.min_size,
        :max_size => new_resource.max_size,
        :availability_zones => availability_zones
      }

      auto_scaling_opts[:desired_capacity] = new_resource.desired_capacity if new_resource.desired_capacity
      auto_scaling_opts[:load_balancers] = new_resource.load_balancers if new_resource.load_balancers

      converge_by "Creating new Auto Scaling group #{new_resource.name} in #{new_driver.aws_config.region}" do
        @existing_group = new_driver.auto_scaling.groups.create(
          new_resource.name,
          auto_scaling_opts
        )

        new_resource.save
      end
    end
  end

  action :delete do
    if existing_group
      converge_by "Deleting Auto Scaling group #{new_resource.name} in #{new_driver.aws_config.region}" do
        existing_group.delete!
      end
    end

    new_resource.delete
  end

  def availability_zones
    @availability_zones ||= new_driver.ec2.availability_zones.reduce([]) { |result, az| result << az }
  end

  def existing_group
    @existing_group ||= begin
                          eg = new_driver.auto_scaling.groups[new_resource.name]
                          eg.exists? ? eg : nil
                        end
  end

  def id
    new_resource.name
  end
end

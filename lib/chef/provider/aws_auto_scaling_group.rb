require 'chef/provider/aws_provider'

class Chef::Provider::AwsAutoScalingGroup < Chef::Provider::AwsProvider
  action :create do
    if existing_group.nil?
      converge_by "Creating new Auto Scaling group #{id} in #{new_resource.region_name}" do
        @existing_group = auto_scaling.groups.create(
          new_resource.name,
          :launch_configuration => new_resource.launch_config,
          :desired_capacity => new_resource.desired_capacity,
          :min_size => new_resource.min_size,
          :max_size => new_resource.max_size,
          :availability_zones => availability_zones
        )

        new_resource.save
      end
    end
  end

  action :delete do
    if existing_group
      converge_by "Deleting Auto Scaling group #{id} in #{new_resource.region_name}" do
        existing_group.delete!
      end
    end

    new_resource.delete
  end

  def availability_zones
    @availability_zones ||= ec2.availability_zones.reduce([]) { |result, az| result << az }
  end

  def existing_group
    @existing_group ||= begin
                          eg = auto_scaling.groups[new_resource.name]
                          eg.exists? ? eg : nil
                        end
  end

  def id
    new_resource.name
  end
end

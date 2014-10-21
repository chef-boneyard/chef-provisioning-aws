require 'chef/provider/aws_provider'

class Chef::Provider::AwsLaunchConfig < Chef::Provider::AwsProvider
  action :create do
    if existing_launch_config.nil?
      converge_by "Creating new Launch Config #{id} in #{new_resource.region_name}" do
        @existing_launch_config = auto_scaling.launch_configurations.create(
          new_resource.name,
          new_resource.image,
          new_resource.instance_type
        )

        new_resource.save
      end
    end
  end

  action :delete do
    if existing_launch_config
      converge_by "Deleting Launch Config #{id} in #{new_resource.region_name}" do
        begin
          existing_launch_config.delete
        rescue AWS::AutoScaling::Errors::ResourceInUse
          sleep 5
          retry
        end
      end
    end

    new_resource.delete
  end

  def existing_launch_config
    @existing_launch_config ||= begin
                                  elc = auto_scaling.launch_configurations[new_resource.name]
                                  elc.exists? ? elc : nil
                                end
  end

  def id
    new_resource.name
  end
end

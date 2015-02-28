require 'chef/provider/aws_provider'

class Chef::Provider::AwsLaunchConfiguration < Chef::Provider::AwsProvider
  action :create do
    if current_aws_object.nil?
      converge_by "Creating new Launch Configuration #{new_resource.name} in #{region}" do
        managed_aws.lookup_options(new_resource.options)
        new_driver.auto_scaling.launch_configurations.create(
          new_resource.name,
          managed_aws.lookup_aws_id(:image, new_resource.image),
          new_resource.instance_type,
          new_resource.options || {}
        )
      end
    end
  end

  action :delete do
    if current_aws_object
      converge_by "Deleting Launch Configuration #{new_resource.name} in #{region}" do
        begin
          current_aws_object.delete
        rescue AWS::AutoScaling::Errors::ResourceInUse
          sleep 5
          retry
        end
      end
    end
  end

end

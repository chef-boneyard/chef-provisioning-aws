require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/resource/aws_image'

class Chef::Provider::AwsLaunchConfiguration < Chef::Provisioning::AWSDriver::AWSProvider
  protected

  def create_aws_object
    image = Chef::Resource::AwsImage.get_aws_object_id(new_resource.image, resource: new_resource)
    instance_type = new_resource.instance_type || new_resource.driver.default_instance_type
    options = AWSResource.lookup_options(new_resource.options || options, resource: new_resource)

    converge_by "Creating new Launch Configuration #{new_resource.name} in #{region}" do
      new_resource.driver.auto_scaling.launch_configurations.create(
        new_resource.name,
        image,
        instance_type,
        options
      )
    end
  end

  def update_aws_object(launch_configuration)
    if new_resource.image
      image = Chef::Resource::AwsImage.get_aws_object_id(new_resource.image, resource: new_resource)
      if image != launch_configuration.image_id
        raise "#{new_resource.to_s}.image = #{new_resource.image} (#{image.id}), but actual launch configuration has image set to #{launch_configuration.image_id}.  Cannot be modified!"
      end
    end
    if new_resource.instance_type
      if new_resource.instance_type != launch_configuration.instance_type
        raise "#{new_resource.to_s}.instance_type = #{new_resource.instance_type}, but actual launch configuration has instance_type set to #{launch_configuration.instance_type}.  Cannot be modified!"
      end
    end
    # TODO compare options
  end

  def destroy_aws_object(launch_configuration)
    converge_by "delete Launch Configuration #{new_resource.name} in #{region}" do
      # TODO add a timeout here.
      # TODO is InUse really a status guaranteed to go away??
      begin
        launch_configuration.delete
      rescue AWS::AutoScaling::Errors::ResourceInUse
        sleep 5
        retry
      end
    end
  end

end

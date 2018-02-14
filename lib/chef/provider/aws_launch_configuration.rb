require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/resource/aws_image'
require 'base64'

class Chef::Provider::AwsLaunchConfiguration < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_launch_configuration

  protected

  def create_aws_object
    image_id = Chef::Resource::AwsImage.get_aws_object_id(new_resource.image, resource: new_resource)
    instance_type = new_resource.instance_type || new_resource.driver.default_instance_type
    options = AWSResource.lookup_options(new_resource.options || options, resource: new_resource)
    options[:launch_configuration_name] = new_resource.name if new_resource.name
    options[:image_id] = image_id
    options[:instance_type] = instance_type
    if options[:user_data]
      options[:user_data] = ensure_base64_encoded(options[:user_data])
    end

    converge_by "create launch configuration #{new_resource.name} in #{region}" do
      new_resource.driver.auto_scaling_client.create_launch_configuration(options)
    end
  end

  def update_aws_object(launch_configuration)
    if new_resource.image
      image_id = Chef::Resource::AwsImage.get_aws_object_id(new_resource.image, resource: new_resource)
      if image_id != launch_configuration.image_id
        raise "#{new_resource.to_s}.image = #{new_resource.image}, but actual launch configuration has image set to #{launch_configuration.image_id}.  Cannot be modified!"
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
    converge_by "delete launch configuration #{new_resource.name} in #{region}" do
      # TODO add a timeout here.
      # TODO is InUse really a status guaranteed to go away??
      begin
        new_resource.driver.auto_scaling_client.delete_launch_configuration(launch_configuration_name: launch_configuration.launch_configuration_name)
      rescue ::Aws::AutoScaling::Errors::ResourceInUse
        sleep 5
        retry
      end
    end
  end

  private

  def ensure_base64_encoded(data)
    begin
      Base64.strict_decode64(data)
      return data
    rescue ArgumentError
      return Base64.encode64(data)
    end
  end

end

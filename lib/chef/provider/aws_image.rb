require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsImage < Chef::Provisioning::AWSDriver::AWSProvider
  def destroy_aws_object(image)
    converge_by "delete image #{new_resource.name} (#{image.id}) in #{region}" do
      image.delete
    end
  end
end

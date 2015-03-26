require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsInstance < Chef::Provisioning::AWSDriver::AWSProvider
  def destroy_aws_object(instance)
    converge_by "delete instance #{new_resource.name} (#{instance.id}) in VPC #{instance.vpc.id} in #{region}" do
      instance.delete
    end
  end
end

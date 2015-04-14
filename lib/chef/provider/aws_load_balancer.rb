require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsLoadBalancer < Chef::Provisioning::AWSDriver::AWSProvider
  def destroy_aws_object(load_balancer)
    converge_by "delete load balancer #{new_resource.name} (#{load_balancer.id}) in VPC #{load_balancer.vpc.id} in #{region}" do
      load_balancer.delete
    end
  end
end

require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsLoadBalancer < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_load_balancer

  def destroy_aws_object(load_balancer)
    converge_by "delete load balancer #{new_resource.name} (#{load_balancer.name}) in #{region}" do
      load_balancer.delete
    end
  end
end

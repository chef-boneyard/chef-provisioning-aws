require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsLoadBalancer < Chef::Provisioning::AWSDriver::AWSProvider

  def aws_tagger
    @aws_tagger ||= begin
      elb_strategy = Chef::Provisioning::AWSDriver::TaggingStrategy::ELB.new(
        new_resource.driver.elb_client,
        new_resource.name,
        new_resource.aws_tags
      )
      Chef::Provisioning::AWSDriver::AWSTagger.new(elb_strategy, action_handler)
    end
  end

  def converge_tags
    aws_tagger.converge_tags
  end

  provides :aws_load_balancer

  def destroy_aws_object(load_balancer)
    converge_by "delete load balancer #{new_resource.name} (#{load_balancer.name}) in #{region}" do
      load_balancer.delete
    end
  end
end

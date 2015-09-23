require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/provisioning/aws_driver/aws_taggable'

class Chef::Resource::AwsLoadBalancer < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type AWS::ELB::LoadBalancer

  attribute :name, kind_of: String,  name_attribute: true

  attribute :load_balancer_id, kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^elb-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    result = driver.elb.load_balancers[name]
    result && result.exists? ? result : nil
  end
end

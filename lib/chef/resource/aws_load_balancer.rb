require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/provisioning/aws_driver/aws_taggable'

class Chef::Resource::AwsLoadBalancer < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::AutoScaling::LoadBalancer

  attribute :name, kind_of: String,  name_attribute: true

  attribute :load_balancer_id, kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^elb-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    result=nil
    begin
      result = driver.elb.describe_load_balancers({ load_balancer_names: [name] }).load_balancer_descriptions
      if result.length == 1
        result = result[0]
      else
        raise "Must have 0 or 1 load balancers which match name!"
      end
    rescue ::Aws::ElasticLoadBalancing::Errors::LoadBalancerNotFound => e
      Chef::Log.debug("No loadbalancer named #{name} - returning nil!")
      result = nil
    end 
    result
  end
end

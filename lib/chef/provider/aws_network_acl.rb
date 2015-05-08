require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/resource/aws_vpc'
require 'retryable'

class Chef::Provider::AwsNetworkAcl < Chef::Provisioning::AWSDriver::AWSProvider
  def action_create
    network_acl = super

    apply_rules(network_acl)

    link_subnets(network_acl)
  end

  protected

  def create_aws_object
    converge_by "Creating new Network ACL #{new_resource.name} in #{region}" do
      options = {}
      options[:vpc] = new_resource.vpc if new_resource.vpc
      options = AWSResource.lookup_options(options, resource: new_resource)

      Chef::Log.debug("VPC: #{options[:vpc]}")

      network_acl = new_resource.driver.ec2.network_acls.create(options)
      Retryable.retryable(:tries => 15, :sleep => 1, :on => AWS::EC2::Errors::InvalidNetworkAclID::NotFound) do
        network_acl.tags['Name'] = new_resource.name
      end
      network_acl
    end
  end

  def update_aws_object(network_acl)
    if !new_resource.vpc.nil?
      desired_vpc = Chef::Resource::AwsVpc.get_aws_object_id(new_resource.vpc, resource: new_resource)
      if desired_vpc != network_acl.vpc_id
        raise "Network ACL VPC cannot be changed after being created!  Desired VPC for #{new_resource.to_s} was #{new_resource.vpc} (#{desired_vpc}) and actual VPC is #{network_acl.vpc_id}"
      end
    end
    apply_rules(network_acl)
    link_subnets(network_acl)
  end

  def destroy_aws_object(network_acl)
    # TODO if purging, do we need to destory the linked subnets?
    converge_by "delete #{new_resource.to_s} in #{region}" do
      network_acl.delete
    end
  end

  private

  def apply_rules(network_acl)

  end

  def link_subnets(network_acl)

  end

end

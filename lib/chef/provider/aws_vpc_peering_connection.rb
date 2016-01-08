require 'chef/provisioning/aws_driver/aws_provider'
require 'retryable'

class Chef::Provider::AwsVpcPeeringConnection < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_vpc_peering_connection

  def action_create
    vpc_peering_connection = super
    accept_connection(vpc_peering_connection, new_resource)
  end

  def action_accept
    existing_vpc_peering_connection = new_resource.aws_object
    accept_connection(existing_vpc_peering_connection, new_resource)
  end

  protected

  def create_aws_object
    if new_resource.vpc.nil?
      raise "VCP peering connection create action for '#{new_resource.name}' requires the 'vpc' attribute."
    elsif new_resource.peer_vpc.nil?
      raise "VCP peering connection create action for '#{new_resource.name}' requires the 'peer_vpc' attribute."
    end

    options = {}
    options[:vpc_id] = new_resource.vpc
    options[:peer_vpc_id] = new_resource.peer_vpc
    options[:peer_owner_id] = new_resource.peer_owner_id unless new_resource.peer_owner_id.nil?

    ## for vpc and peer_vpc, don't use a lookup if they're a string that is an actual VPC identifier - it's entirely possible we dont know about it in our scope (ie, 3rd party account or manage by separate tools)
    unless new_resource.vpc.class == String && new_resource.vpc.to_s =~ /^vpc-.*/
      options[:vpc_id] = Chef::Resource::AwsVpc.get_aws_object_id(new_resource.vpc, resource: new_resource)
    end
    unless new_resource.peer_vpc.class == String && new_resource.peer_vpc.to_s =~ /^vpc-.*/
      options[:peer_vpc_id] = Chef::Resource::AwsVpc.get_aws_object_id(
        new_resource.peer_vpc, resource: new_resource)
    end

    ec2_resource = new_resource.driver.ec2_resource
    vpc = ec2_resource.vpc(options[:vpc_id])

    converge_by "create peering connection #{new_resource.name} in VPC #{new_resource.vpc} (#{vpc.id}) and region #{region}" do
      vpc_peering_connection = vpc.request_vpc_peering_connection(options)

      retry_with_backoff(::Aws::EC2::Errors::ServiceError) do
        ec2_resource.create_tags({
          :resources => [vpc_peering_connection.id],
          :tags => [
            {
              :key => "Name",
              :value => new_resource.name
            }
          ]
        })
      end
      vpc_peering_connection
    end
  end

  def update_aws_object(vpc_peering_connection)
    vpc_id = vpc_peering_connection.requester_vpc_info.vpc_id
    peer_vpc_id = vpc_peering_connection.accepter_vpc_info.vpc_id
    peer_owner_id = vpc_peering_connection.accepter_vpc_info.owner_id

    ## for vpc and peer_vpc, don't use a lookup if they're a string that is an actual VPC identifier - it's entirely possible we dont know about it in our scope (ie, 3rd party account or manage by separate tools)
    if new_resource.vpc.class == String && new_resource.vpc.to_s =~ /^vpc-.*/
      desired_vpc_id = new_resource.vpc
    else
      desired_vpc_id = Chef::Resource::AwsVpc.get_aws_object_id(new_resource.vpc, resource: new_resource)
    end
    if new_resource.peer_vpc.class == String && new_resource.peer_vpc.to_s =~ /^vpc-.*/
      desired_peer_vpc_id = new_resource.peer_vpc
    else
      desired_peer_vpc_id = Chef::Resource::AwsVpc.get_aws_object_id(
        new_resource.peer_vpc, resource: new_resource)
    end

    desired_peer_owner_id = new_resource.peer_owner_id

    if desired_vpc_id && vpc_id != desired_vpc_id
      raise "VCP peering connection requester vpc cannot be changed after being created! Desired requester vpc id for #{new_resource.name} (#{vpc_peering_connection.id}) was \"#{desired_vpc_id}\" and actual id is \"#{vpc_id}\""
    end
    if desired_peer_vpc_id && peer_vpc_id != desired_peer_vpc_id
      raise "VCP peering connection accepter vpc cannot be changed after being created! Desired accepter vpc id for #{new_resource.name} (#{vpc_peering_connection.id}) was \"#{desired_peer_vpc_id}\" and actual id is \"#{peer_vpc_id}\""
    end
    if desired_peer_owner_id && peer_owner_id != desired_peer_owner_id
      raise "VCP peering connection accepter owner id vpc cannot be changed after being created! Desired accepter vpc owner id for #{new_resource.name} (#{vpc_peering_connection.id}) was \"#{desired_peer_owner_id}\" and actual owner id is \"#{peer_owner_id}\""
    end
  end

  def destroy_aws_object(vpc_peering_connection)
    converge_by "delete #{new_resource.to_s} in #{region}" do
      unless ['deleted', 'failed', 'deleting'].include? vpc_peering_connection.status.code
        vpc_peering_connection.delete
      end
    end
  end

  private

  def accept_connection(vpc_peering_connection, new_resource)
    if new_resource.peer_owner_id.nil? or new_resource.peer_owner_id == new_resource.driver.account_id
      vpc_peering_connection.accept
    end
  end
end

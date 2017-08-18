#require 'chef/provisioning/aws_driver/aws_provider'
require 'retryable'

class Chef::Provider::AwsNatGateway < Chef::Provisioning::AWSDriver::AWSProvider

  provides :aws_nat_gateway

  protected

  def create_aws_object
    if new_resource.subnet.nil?
      raise "Nat Gateway create action for '#{new_resource.name}' requires the 'subnet' attribute."
    end
    subnet = Chef::Resource::AwsSubnet.get_aws_object(new_resource.subnet, resource: new_resource)

    if new_resource.eip_address.nil?
      # TODO Ideally it would be nice to automatically manage an eip address but
      # the lack of tagging support and the limited SDK interaction with these two
      # resources makes that too hard right now. So we force the user to manage their
      # eip address as a seperate resource.
      raise "Nat Gateway create action for '#{new_resource.name}' requires the 'eip_address' attribute."
    end
    eip_address = Chef::Resource::AwsEipAddress.get_aws_object(new_resource.eip_address, resource: new_resource)

    converge_by "create nat gateway #{new_resource.name} in region #{region} for subnet #{subnet}" do
      options = {
          subnet_id: subnet.id,
          allocation_id: eip_address.allocation_id
      }

      nat_gateway = new_resource.driver.ec2_resource.create_nat_gateway(options)
      wait_for_state(nat_gateway, :available)
      nat_gateway
    end
  end

  def update_aws_object(nat_gateway)
    subnet_id = Chef::Resource::AwsSubnet.get_aws_object_id(new_resource.subnet, resource: new_resource) if new_resource.subnet
    if subnet_id != nat_gateway.subnet_id
      raise "Nat gateway subnet cannot be changed after being created! Desired subnet for #{new_resource.name} (#{nat_gateway.id}) was \"#{nat_gateway.subnet_id}\" and actual description is \"#{subnet_id}\""
    end

    if new_resource.eip_address
      eip_address = Chef::Resource::AwsEipAddress.get_aws_object(new_resource.eip_address, resource: new_resource)
      if eip_address.nil? or eip_address.allocation_id != nat_gateway.nat_gateway_addresses.first.allocation_id
        raise "Nat gateway elastic ip address cannot be changed after being created! Desired elastic ip address for #{new_resource.name} (#{nat_gateway.id}) was \"#{nat_gateway.nat_gateway_addresses.first.allocation_id}\" and actual description is \"#{eip_address.allocation_id}\""
      end
    end
  end

  def destroy_aws_object(nat_gateway)
    converge_by "delete nat gateway #{new_resource.name} in region #{region} for subnet #{nat_gateway.subnet_id}" do
      nat_gateway.delete
      wait_for_state(nat_gateway, :deleted)
    end
  end
end

require 'chef/provider/aws_provider'
require 'chef/provisioning/machine_spec'
require 'cheffish'

class Chef::Provider::AwsEipAddress < Chef::Provider::AwsProvider

  action :create do
    if existing_ip == nil
      converge_by "Creating new EIP address in #{new_driver.aws_config.region}" do
        eip = new_driver.ec2.elastic_ips.create :vpc => new_resource.associate_to_vpc
        new_resource.public_ip eip.public_ip
        new_resource.domain eip.domain
        new_resource.instance_id eip.instance_id
      end
    else
      new_resource.public_ip existing_ip.public_ip
      new_resource.domain existing_ip.domain
      new_resource.instance_id existing_ip.instance_id
    end
    new_resource.save
  end

  action :delete do
    if existing_ip
      converge_by "Deleting EIP Address #{new_resource.name} in #{new_driver.aws_config.region}" do
        #if it's attached to something in a vpc, disassociate first
        if existing_ip.instance_id != nil && existing_ip.domain == 'vpc'
          existing_ip.disassociate
        end
        existing_ip.delete
        new_resource.delete
      end
    end
  end

  action :associate do
    converge_by "Associating EIP Address #{new_resource.name} in #{new_driver.aws_config.region}" do
      if existing_ip == nil
        action_create
      end
        eip = new_driver.ec2.elastic_ips[new_resource.public_ip]
      begin
        spec = Chef::Provisioning::ChefMachineSpec.get(new_resource.machine)
        if spec == nil
          Chef::Application.fatal!("Could not find machine #{new_resource.machine}")
        else
          eip.associate :instance => spec.location['instance_id']
        end
        new_resource.instance_id eip.instance_id
      rescue => e
        Chef::Application.fatal!("Error Associating EIP: #{e}")
      end
      new_resource.save
    end
  end

  action :disassociate do
    converge_by "Disassociating EIP Address #{new_resource.name} in #{new_driver.aws_config.region}" do
      begin
        if existing_ip != nil
          existing_ip.disassociate
          new_resource.instance_id nil
          new_resource.save
        else
          Chef::Log.warn("No EIP found to disassociate")
        end
      rescue => e
        Chef::Application.fatal!("Error Disassociating EIP: #{e}")
      end
    end
  end

  def existing_ip
    new_resource.hydrate
    @existing_ip ||=  new_resource.public_ip == nil ? nil : begin
      eip = new_driver.ec2.elastic_ips[new_resource.public_ip]
      eip
    rescue => e
      Chef::Application.fatal!("Error looking for EIP Address: #{e}")
      nil
    end
  end


end

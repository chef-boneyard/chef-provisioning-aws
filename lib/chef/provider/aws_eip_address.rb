require 'chef/provider/aws_provider'
require 'chef/provisioning/machine_spec'
require 'cheffish'

class Chef::Provider::AwsEipAddress < Chef::Provider::AwsProvider

  action :delete do
    if aws_object
      converge_by "Deleting EIP Address #{new_resource.name} in #{region}" do
        #if it's attached to something in a vpc, disassociate first
        if aws_object.instance_id != nil && aws_object.domain == 'vpc'
          aws_object.disassociate
        end
        aws_object.delete
        delete_spec
      end
    end
  end

  action :associate do
    converge_by "Associating EIP Address #{new_resource.name} in #{region}" do
      eip = aws_object
      if !eip
        converge_by "Creating new EIP address in #{region}" do
          eip = aws_driver.ec2.elastic_ips.create vpc: new_resource.associate_to_vpc
          save_managed_entry(public_ip: eip.public_ip)
        end
      end

      # Associate the EIP with the given machine
      if new_resource.instance_id
        begin
          eip.associate :instance => managed_aws.lookup_aws_id(:instance, new_resource.instance_id)
        rescue => e
          Chef::Application.fatal!("Error Associating EIP: #{e}")
        end
      end
    end
  end

  action :disassociate do
    converge_by "Disassociating EIP Address #{new_resource.name} in #{region}" do
      begin
        if aws_object != nil
          aws_object.disassociate
        else
          Chef::Log.warn("No EIP found to disassociate")
        end
      rescue => e
        Chef::Application.fatal!("Error Disassociating EIP: #{e}")
      end
    end
  end

end

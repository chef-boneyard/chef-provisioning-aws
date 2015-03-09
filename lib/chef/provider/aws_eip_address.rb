require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/machine_spec'
require 'cheffish'

class Chef::Provider::AwsEipAddress < Chef::Provisioning::AWSDriver::AWSProvider

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      #if it's attached to something in a vpc, disassociate first
      if aws_object.instance_id != nil && aws_object.domain == 'vpc'
        converge_by "Disassociating EIP Address #{new_resource.name} (#{aws_object.public_ip}) from #{aws_object.instance_id}" do
          aws_object.disassociate
        end
      end
      converge_by "Deleting EIP Address #{new_resource.name} (#{aws_object.public_ip}) in #{region}" do
        aws_object.delete
      end
    end
    new_resource.delete_managed_entry(action_handler)
  end

  action :associate do
    aws_object = new_resource.aws_object

    # TODO this is not test-and-set at all.  Whence the test?  Needs a reset
    converge_by "Associating EIP Address #{new_resource.name} in #{region}" do
      if !aws_object
        converge_by "Creating new EIP address in #{region}" do
          aws_object = driver.ec2.elastic_ips.create vpc: new_resource.associate_to_vpc
          new_resource.save_managed_entry(aws_object, action_handler)
        end
      end

      # Associate the EIP with the given machine
      options = lookup_options(:instance => new_resource.instance_id)
      if !aws_object.instance || options[:instance] != aws_object.instance.id
        converge_by "Associating EIP Address #{new_resource.name} (#{aws_object.public_ip}) with #{options[:instance]}" do
          aws_object.associate options
        end
      end
    end
  end

  action :disassociate do
    if aws_object && aws_object.instance_id
      converge_by "Disassociating EIP Address #{new_resource.name} (#{aws_object}) from #{aws_object.instance_id} in #{region}" do
        aws_object.disassociate
      end
    end
  end

end

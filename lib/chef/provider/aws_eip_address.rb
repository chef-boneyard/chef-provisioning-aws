require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/resource/aws_instance'
require 'chef/provisioning/machine_spec'
require 'cheffish'

class Chef::Provider::AwsEipAddress < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_eip_address

  def action_create
    elastic_ip = super

    if !new_resource.machine.nil?
      update_association(elastic_ip)
    end
  end

  protected

  def create_aws_object
    converge_by "create Elastic IP address in #{region}" do
      associate_to_vpc = new_resource.associate_to_vpc
      if associate_to_vpc.nil?
        if desired_instance.is_a?(AWS::EC2::Instance) || desired_instance.is_a?(::Aws::EC2::Instance)
          associate_to_vpc = !!desired_instance.vpc_id
          Chef::Log.debug "Since associate_to_vpc is not specified and instance #{new_resource.machine} (#{desired_instance.id}) and #{associate_to_vpc ? "is" : "is not"} in a VPC, setting associate_to_vpc to #{associate_to_vpc}."
        end
      end
      new_resource.driver.ec2.elastic_ips.create vpc: new_resource.associate_to_vpc
    end
  end

  def update_aws_object(elastic_ip)
    if !new_resource.associate_to_vpc.nil?
      if !!new_resource.associate_to_vpc != !!elastic_ip.vpc?
        raise "#{new_resource.to_s}.associate_to_vpc = #{new_resource.associate_to_vpc}, but actual IP address has vpc? set to #{elastic_ip.vpc?}.  Cannot be modified!"
      end
    end
  end

  def destroy_aws_object(elastic_ip)
    #if it's attached to something in a vpc, disassociate first
    if elastic_ip.instance_id != nil && elastic_ip.domain == 'vpc'
      converge_by "dissociate Elastic IP address #{new_resource.name} (#{elastic_ip.public_ip}) from #{elastic_ip.instance_id}" do
        elastic_ip.disassociate
      end
    end
    converge_by "delete Elastic IP address #{new_resource.name} (#{elastic_ip.public_ip}) in #{region}" do
      elastic_ip.delete
    end
  end

  private

  def desired_instance
    if !defined?(@desired_instance)
      if new_resource.machine == false
        @desired_instance = false
      else
        @desired_instance = Chef::Resource::AwsInstance.get_aws_object(new_resource.machine, resource: new_resource)
      end
    end
    @desired_instance
  end

  def update_association(elastic_ip)
    #
    # If we were told to associate the IP to a machine, do so
    #
    if desired_instance.is_a?(AWS::EC2::Instance) || desired_instance.is_a?(::Aws::EC2::Instance)
      if desired_instance.id != elastic_ip.instance_id
        converge_by "associate Elastic IP address #{new_resource.name} (#{elastic_ip.public_ip}) with #{new_resource.machine} (#{desired_instance.id})" do
          elastic_ip.associate instance: desired_instance.id
        end
      end

    #
    # If we were told to set the association to false, disassociate it.
    #
    else
      if elastic_ip.associated?
        converge_by "disassociate Elastic IP address #{new_resource.name} (#{elastic_ip.public_ip}) from #{elastic_ip.instance_id} in #{region}" do
          elastic_ip.disassociate
        end
      end
    end

  end

end

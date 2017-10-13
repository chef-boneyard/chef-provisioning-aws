require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/resource/aws_subnet'
require 'chef/resource/aws_eip_address'

class Chef::Resource::AwsNetworkInterface < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::EC2::NetworkInterface, option_names: []

  attribute :name,                   kind_of: String, name_attribute: true

  attribute :network_interface_id,   kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^eni-[a-f0-9]{8}$/ ? name : nil
  }

  attribute :subnet,                 kind_of: [ String, ::Aws::EC2::Subnet, AwsSubnet ]

  attribute :private_ip_address,     kind_of: String

  attribute :description,            kind_of: String

  attribute :security_groups,        kind_of: Array #(Array<SecurityGroup>, Array<String>)

  attribute :machine,                kind_of: [ String, FalseClass, AwsInstance, ::Aws::EC2::Instance, ::Aws::EC2::Instance ]

  attribute :device_index,           kind_of: Integer

  # TODO implement eip address association
  #attribute :elastic_ip_address,     kind_of: [ String, ::Aws::OpsWorks::Types::ElasticIp, AwsEipAddress, FalseClass ]

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2_resource.network_interface(id) if id
    result && exists?(result) ? result : nil
  end

  def exists?(result)
    return true if result.data
  rescue ::Aws::EC2::Errors::InvalidNetworkInterfaceIDNotFound
    return false
  end
end

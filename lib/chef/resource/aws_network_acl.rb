require 'chef/provisioning/aws_driver/aws_resource_with_entry'
require 'chef/resource/aws_vpc'
require 'chef/resource/aws_subnet'

class Chef::Resource::AwsNetworkAcl < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::EC2::NetworkAcl

  #
  # The name of this network acl.
  #
  attribute :name, kind_of: String, name_attribute: true

  #
  # The VPC of this network acl.
  #
  # May be one of:
  # - The name of an `aws_vpc` Chef resource.
  # - An actual `aws_vpc` resource.
  # - An AWS `VPC` object.
  #
  attribute :vpc, kind_of: [ String, AwsVpc, ::Aws::EC2::Vpc ]

  #
  # Accepts rules in the format:
  # [
  #   { rule_number: 100, action: <:deny|:allow>, protocol: -1, cidr_block: '0.0.0.0/0', port_range: 80..80 }
  # ]
  #
  # `cidr_block` will be a source if it is an inbound rule, or a destination if it is an outbound rule
  #
  # If `inbound_rules` or `outbound_rules` is unset, respective current rules will not be changed.
  # However, if either is set to `[]` all respective current rules will be removed.
  #
  attribute :inbound_rules,
            kind_of: [ Array, Hash ],
            coerce: proc { |v| v && [v].flatten }

  attribute :outbound_rules,
            kind_of: [ Array, Hash ],
            coerce: proc { |v| v && [v].flatten }

  attribute :network_acl_id,
            kind_of: String,
            aws_id_attribute: true,
            default: lazy {
              name =~ /^acl-[a-f0-9]{8}$/ ? name : nil
            }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2_resource.network_acl(id) if id
    result && exists?(result) ? result : nil
  end

  def exists?(result)
    return true if result.data
  rescue ::Aws::EC2::Errors::InvalidNetworkAclIDNotFound
    return false
  end

end

require 'chef/provisioning/aws_driver/aws_resource_with_entry'
require 'chef/resource/aws_vpc'
require 'chef/resource/aws_subnet'

class Chef::Resource::AwsNetworkAcl < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type AWS::EC2::NetworkACL

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
  attribute :vpc, kind_of: [ String, AwsVpc, AWS::EC2::VPC ]

  #
  # Accepts rules in the format:
  # [
  #   { rule_number: 100, action: <:deny|:allow>, protocol: -1, cidr_block: '0.0.0.0/0', port_range: 80..80 }
  # ]
  #
  # `cidr_block` will be a source if it is an inbound rule, or a destination if it is an outbound rule
  #
  # If `inbound_rules` or `outbound_rules` is `nil`, respective current rules will not be changed.
  # However, if either is set to `[]` all respective current rules will be removed.
  #
  attribute :inbound_rules,
            kind_of: [ Array, Hash ],
            coerce: proc { |v| [v].flatten }

  attribute :outbound_rules,
            kind_of: [ Array, Hash ],
            coerce: proc { |v| [v].flatten }

  attribute :network_acl_id,
            kind_of: String,
            aws_id_attribute: true,
            default: lazy {
              name =~ /^acl-[a-f0-9]{8}$/ ? name : nil
            }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2.network_acls[id] if id
    begin
      # network_acls don't have an `exists?` method so have to query an attribute
      result.vpc_id
      result
    rescue AWS::EC2::Errors::InvalidNetworkAclID::NotFound
      nil
    end
  end

end

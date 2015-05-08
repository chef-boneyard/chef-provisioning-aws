require 'chef/provisioning/aws_driver/aws_resource_with_entry'
require 'chef/resource/aws_vpc'
require 'chef/resource/aws_subnet'

class Chef::Resource::AwsNetworkAcl < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::EC2::NetworkACL

  #
  # The name of this network acl.
  #
  attribute :name,           kind_of: String, name_attribute: true

  #
  # The VPC of this network acl.
  #
  # May be one of:
  # - The name of an `aws_vpc` Chef resource.
  # - An actual `aws_vpc` resource.
  # - An AWS `VPC` object.
  #
  attribute :vpc,            kind_of: [ String, AwsVpc, AWS::EC2::VPC ]

  #
  # Accepts rules in the format:
  # [
  #   { port: 22, protocol: :tcp, sources: [<source>, <source>, ...], rule_number: 100,  rule: <:allow/:deny>}
  # ]
  #
  #
  # <source> will be a source if it is an inbound rule, or a destination if it is an outbound rule
  # <source> must be a :
  # - <CIDR>: An IP or CIDR of IPs to talk to
  #   - `inbound_rules '1.2.3.4' => 80`
  #   - `inbound_rules '1.2.3.4/24' => 80`
  #   - `outbound_rules '5.6.7.8' => 22`
  #
  attribute :inbound_rules,  kind_of: [ Array, Hash ]
  attribute :outbound_rules, kind_of: [ Array, Hash ]

  attribute :subnet,         kind_of: [ String, AWS::EC2::Subnet, AwsSubnet ]

  attribute :network_acl_id, kind_of: String, aws_id_attribute: true, lazy_default: proc {
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

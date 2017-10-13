require 'chef/provisioning/aws_driver/aws_resource_with_entry'

#
# DHCP options for use by VPCs.
#
# If you specify nothing, the DHCP options set will use 'AmazonProvidedDNS' for its
# domain name servers and all other values will be empty.
#
# API documentation for the AWS Ruby SDK for DHCP Options (and the object returned from `aws_object` can be found here:
#
# - http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_DHCP_Options.html
#
class Chef::Resource::AwsDhcpOptions < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::EC2::DhcpOptions

  #
  # The Chef "idempotence name" of this DHCP options set.
  #
  attribute :name, kind_of: String, name_attribute: true

  #
  # A domain name of your choice (e.g., example.com).
  #
  attribute :domain_name, kind_of: String

  #
  # The IP addresses of domain name servers. You can specify up to four addresses.
  #
  # Defaults to "AmazonProvidedDNS"
  #
  attribute :domain_name_servers, kind_of: Array, coerce: proc { |v| Array[v].flatten }

  #
  # The IP addresses of Network Time Protocol (NTP) servers. You can specify up to four addresses.
  #
  attribute :ntp_servers, kind_of: Array, coerce: proc { |v| Array[v].flatten }

  #
  # The IP addresses of NetBIOS name servers. You can specify up to four addresses.
  #
  attribute :netbios_name_servers, kind_of: Array, coerce: proc { |v| Array[v].flatten }

  #
  # Value indicating the NetBIOS node type (1, 2, 4, or 8). For more information about the values, go to RFC 2132. We recommend you only use 2 at this time (broadcast and multicast are currently not supported).
  #
  attribute :netbios_node_type, kind_of: Integer

  attribute :dhcp_options_id, kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^dopt-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    ec2_resource = ::Aws::EC2::Resource.new(driver.ec2)
    result = ec2_resource.dhcp_options(id) if id
    result && exists?(result) ? result : nil
  end

  def exists?(result)
    return true if result.data
  rescue ::Aws::EC2::Errors::InvalidDhcpOptionIDNotFound
    return false
  end
end

require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/resource/aws_vpc'
require 'chef/provisioning/aws_driver/exceptions'

class Chef::Resource::AwsSecurityGroup < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::EC2::SecurityGroup,
               id: :id,
               option_names: [:security_group, :security_group_id, :security_group_name]

  attribute :name,          kind_of: String, name_attribute: true
  attribute :vpc,           kind_of: [ String, AwsVpc, ::Aws::EC2::Vpc ]
  attribute :description,   kind_of: String

  #
  # Accepts rules in the format:
  # [
  #   { port: 22, protocol: :tcp, sources: [<source>, <source>, ...] }
  # ]
  #
  # Or:
  # {
  #   <permitted_source> => <port>,
  #   ...
  # }
  #
  # Where <port> is one of:
  # - <port number/range>: the port number. e.g. `80`; or a port range: `1024..2048`
  # - [ <port number/range>, <protocol> ] or [ <protocol>, <number> ], e.g. `[ 80, :http ]`
  # - { port: <port number/range>, protocol: <protocol> }, e.g. { port: 80, protocol: :http }
  #
  # And <permitted_source> is one of:
  # - <CIDR>: An IP or CIDR of IPs to talk to.
  #   - `inbound_rules '1.2.3.4' => 80`
  #   - `inbound_rules '1.2.3.4/24' => 80`
  # - <Security Group>: A security group to authorize.
  #   - `inbound_rules 'mysecuritygroup'`
  #   - `inbound_rules { security_group: 'mysecuritygroup' }`
  #   - `inbound_rules 'sg-1234abcd' => 80`
  #   - `inbound_rules aws_security_group('mysecuritygroup') => 80`
  #   - `inbound_rules AWS.ec2.security_groups.first => 80`
  # - <Load Balancer>: A load balancer to authorize.
  #   - `inbound_rules { load_balancer: 'myloadbalancer' } => 80`
  #   - `inbound_rules 'elb-1234abcd' => 80`
  #   - `inbound_rules load_balancer('myloadbalancer') => 80`
  #   - `inbound_rules AWS.ec2.security_groups.first => 80`
  #
  attribute :inbound_rules,  kind_of: [ Array, Hash ]
  attribute :outbound_rules, kind_of: [ Array, Hash ]

  attribute :security_group_id, kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^sg-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    if security_group_id
      result = driver.ec2_resource.security_group(security_group_id)
    else
      # Names are unique within a VPC.  Try to search by name and narroy by VPC, if
      # provided
      if vpc
        vpc_object = Chef::Resource::AwsVpc.get_aws_object(vpc, resource: self)
        results=vpc_object.security_groups.to_a.select { |s| s.group_name == name or s.id == name }
      else
        results=driver.ec2_resource.security_groups.to_a.select { |s| s.group_name == name or s.id == name }
      end
      if results.size >= 2
        raise ::Chef::Provisioning::AWSDriver::Exceptions::MultipleSecurityGroupError.new(name, results)
      end
      result = results.first
    end
    result ? result : nil
  end
end

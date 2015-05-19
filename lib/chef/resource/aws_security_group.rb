require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/resource/aws_vpc'
require 'chef/provisioning/aws_driver/exceptions'

class Chef::Resource::AwsSecurityGroup < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::EC2::SecurityGroup, id: :name

  attribute :name,          kind_of: String, name_attribute: true
  attribute :vpc,           kind_of: [ String, AwsVpc, AWS::EC2::VPC ]
  attribute :description,   kind_of: String

  # This should be a hash of tags to apply to the AWS object
  # TODO this is duplicated from AWSResourceWithEntry
  #
  # @param aws_tags [Hash] Should be a hash of keys & values to add.  Keys and values
  #        can be provided as symbols or strings, but will be stored in AWS as strings.
  attribute :aws_tags, kind_of: Hash

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

  attribute :security_group_id, kind_of: String, aws_id_attribute: true, lazy_default: proc {
    name =~ /^sg-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    if security_group_id
      result = driver.ec2.security_groups[security_group_id]
    else
      # Names are unique within a VPC.  Try to search by name and narroy by VPC, if
      # provided
      if vpc
        vpc_object = Chef::Resource::AwsVpc.get_aws_object(vpc, resource: self)
        results = vpc_object.security_groups.filter('group-name', name).to_a
      else
        results = driver.ec2.security_groups.filter('group-name', name).to_a
      end
      if results.size >= 2
        raise ::Chef::Provisioning::AWSDriver::Exceptions::MultipleSecurityGroupError.new(name, results)
      end
      result = results.first
    end
    result && result.exists? ? result : nil
  end
end

require 'chef/provisioning/aws_driver/aws_resource_with_entry'
require 'chef/resource/aws_vpc'

class Chef::Resource::AwsSecurityGroup < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::EC2::SecurityGroup

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,           kind_of: String, name_attribute: true
  attribute :vpc,            kind_of: [ String, AwsVpc, AWS::EC2::VPC ]
  attribute :description,    kind_of: String

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
    driver, id = get_driver_and_id
    result = driver.ec2.security_groups[id] if id
    result && result.exists? ? result : nil
  end
end

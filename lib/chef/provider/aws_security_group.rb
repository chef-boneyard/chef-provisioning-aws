require 'chef/provisioning/aws_driver/aws_provider'
require 'date'
require 'ipaddr'
require 'set'

class Chef::Provider::AwsSecurityGroup < Chef::Provisioning::AWSDriver::AWSProvider

  def action_create
    sg = super

    apply_rules(sg)
  end

  protected

  def create_aws_object
    converge_by "Creating new SG #{new_resource.name} in #{region}" do
      options = { description: new_resource.description }
      options[:vpc] = new_resource.vpc if new_resource.vpc
      options = AWSResource.lookup_options(options, resource: new_resource)
      Chef::Log.debug("VPC: #{options[:vpc]}")

      sg = new_resource.driver.ec2.security_groups.create(new_resource.name, options)
    end
  end

  def update_aws_object(sg)
    if !new_resource.description.nil? && new_resource.description != sg.description
      raise "Security Group descriptions cannot be changed after being created!  Desired description for #{new_resource.name} (#{sg.id}) was \"#{new_resource.description}\" and actual description is \"#{sg.description}\""
    end
    if !new_resource.vpc.nil?
      desired_vpc = Chef::Resource::AwsVpc.get_aws_object_id(new_resource.vpc, resource: new_resource)
      if desired_vpc != sg.vpc_id
        raise "Security Group VPC cannot be changed after being created!  Desired VPC for #{new_resource.name} (#{sg.id}) was #{new_resource.vpc} (#{desired_vpc}) and actual VPC is #{sg.vpc_id}"
      end
    end
    apply_rules(sg)
  end

  def destroy_aws_object(sg)
    converge_by "Deleting SG #{new_resource.name} in #{region}" do
      sg.delete
    end
  end

  private

  def apply_rules(sg)
    vpc = sg.vpc
    if !new_resource.outbound_rules.nil?
      update_outbound_rules(sg, vpc)
    end

    if !new_resource.inbound_rules.nil?
      update_inbound_rules(sg, vpc)
    end
  end

  def update_inbound_rules(sg, vpc)
    #
    # Get desired rules
    #
    desired_rules = {}

    case new_resource.inbound_rules
    when Hash
      new_resource.inbound_rules.each do |sources_spec, port_spec|
        add_rule(desired_rules, get_port_ranges(port_spec), get_actors(vpc, sources_spec))
      end

    when Array
      # [ { port: X, protocol: Y, sources: [ ... ]}]
      new_resource.inbound_rules.each do |rule|
        port_ranges = get_port_ranges(rule)
        add_rule(desired_rules, port_ranges, get_actors(vpc, rule[:sources]))
      end

    else
      raise ArgumentError, "inbound_rules must be a Hash or Array (was #{new_resource.inbound_rules.inspect})"
    end

    #
    # Actually update the rules (remove, add)
    #
    update_rules(desired_rules, sg.ip_permissions_list,

      authorize: proc do |port_range, protocol, actors|
        names = actors.map { |a| a.is_a?(Hash) ? a[:group_id] : a }
        converge_by "authorize #{names.join(', ')} to send traffic to group #{new_resource.name} (#{sg.id}) on port_range #{port_range} with protocol #{protocol}" do
          sg.authorize_ingress(protocol, port_range, *actors)
        end
      end,

      revoke: proc do |port_range, protocol, actors|
        names = actors.map { |a| a.is_a?(Hash) ? a[:group_id] : a }
        converge_by "revoke the ability of #{names.join(', ')} to send traffic to group #{new_resource.name} (#{sg.id}) on port_range #{port_range} with protocol #{protocol}" do
          sg.revoke_ingress(protocol, port_range, *actors)
        end
      end
    )
  end

  def update_outbound_rules(sg, vpc)
    #
    # Get desired rules
    #
    desired_rules = {}

    case new_resource.outbound_rules
    when Hash
      new_resource.outbound_rules.each do |port_spec, sources_spec|
        add_rule(desired_rules, get_port_ranges(port_spec), get_actors(vpc, sources_spec))
      end

    when Array
      # [ { port: X, protocol: Y, sources: [ ... ]}]
      new_resource.outbound_rules.each do |rule|
        port_ranges = get_port_ranges(rule)
        add_rule(desired_rules, port_ranges, get_actors(vpc, rule[:destinations]))
      end

    else
      raise ArgumentError, "outbound_rules must be a Hash or Array (was #{new_resource.outbound_rules.inspect})"
    end

    #
    # Actually update the rules (remove, add)
    #
    update_rules(desired_rules, sg.ip_permissions_list_egress,

      authorize: proc do |port_range, protocol, actors|
        names = actors.map { |a| a.is_a?(Hash) ? a[:group_id] : a }
        converge_by "authorize group #{new_resource.name} (#{sg.id}) to send traffic to #{names.join(', ')} on port_range #{port_range} with protocol #{protocol}" do
          sg.authorize_egress(*actors, ports: port_range, protocol: protocol)
        end
      end,

      revoke: proc do |port_range, protocol, actors|
        names = actors.map { |a| a.is_a?(Hash) ? a[:group_id] : a }
        converge_by "revoke the ability of group #{new_resource.name} (#{sg.id}) to send traffic to #{names.join(', ')} on port_range #{port_range} with protocol #{protocol}" do
          sg.revoke_egress(*actors, ports: port_range, protocol: protocol)
        end
      end
    )
  end

  def update_rules(desired_rules, actual_rules_list, authorize: nil, revoke: nil)
    actual_rules = {}
    actual_rules_list.each do |rule|
      port_range = {
        port_range: rule[:from_port] ? rule[:from_port]..rule[:to_port] : nil,
        protocol: rule[:ip_protocol].to_s.to_sym
      }
      add_rule(actual_rules, [ port_range ], rule[:groups]) if rule[:groups]
      add_rule(actual_rules, [ port_range ], rule[:ip_ranges].map { |r| r[:cidr_ip] }) if rule[:ip_ranges]
    end

    #
    # Get the list of permissions to add and remove
    #
    actual_rules.each do |port_range, actors|
      if desired_rules[port_range]
        intersection = actors & desired_rules[port_range]
        # Anything unhandled in desired_rules will be added
        desired_rules[port_range] -= intersection
        # Anything unhandled in actual_rules will be removed
        actual_rules[port_range] -= intersection
      end
    end

    #
    # Add any new rules
    #
    desired_rules.each do |port_range, actors|
      unless actors.empty?
        authorize.call(port_range[:port_range], port_range[:protocol], actors)
      end
    end

    #
    # Remove any rules no longer in effect
    #
    actual_rules.each do |port_range, actors|
      unless actors.empty?
        revoke.call(port_range[:port_range], port_range[:protocol], actors)
      end
    end
  end

  def add_rule(rules, port_ranges, actors)
    unless actors.empty?
      port_ranges.each do |port_range|
        rules[port_range] ||= Set.new
        rules[port_range] += actors
      end
    end
  end

  def get_port_ranges(port_spec)
    case port_spec
    when Integer
      [ { port_range: port_spec..port_spec, protocol: :tcp } ]
    when Range
      [ { port_range: port_spec, protocol: :tcp } ]
    when Array
      port_spec.map { |p| get_port_ranges(p) }.flatten
    when :icmp
      { port_range: port_spec, protocol: :icmp }
    when Hash
      port_range = port_spec[:port_range] || port_spec[:ports] || port_spec[:port]
      port_range = port_range..port_range if port_range.is_a?(Integer)
      if port_spec[:protocol]
        port_range ||= -1..-1
        [ { port_range: port_range, protocol: port_spec[:protocol].to_s.to_sym || :tcp } ]
      else
        get_port_ranges(port_range)
      end
      # The to_s.to_sym dance is because if you specify a protocol number, AWS symbolifies it,
      # but 26.to_sym doesn't work (so we have to to_s it first).
    when nil
      [ { port_range: nil, protocol: :any } ]
    end
  end

  #
  # Turns an actor_spec into a uniform array, containing CIDRs, AWS::EC2::LoadBalancers and AWS::EC2::SecurityGroups.
  #
  def get_actors(vpc, actor_spec)
    result = case actor_spec

    # An array is always considered a list of actors.  Each one may follow any supported format.
    when Array
      actor_spec.map { |a| get_actors(vpc, a) }

    # Hashes come in several forms:
    when Hash
      # The default AWS Ruby SDK form with :user_id, :group_id and :group_name forms
      if actor_spec.keys.all? { |key| [ :user_id, :group_id, :group_name ].include?(key) }
        if actor_spec.has_key?(:group_name)
          actor_spec[:group_id] ||= vpc.security_groups.filter('group-name', actor_spec[:group_name]).first.id
        end
        actor_spec[:user_id] ||= new_resource.driver.account_id
        { user_id: actor_spec[:user_id], group_id: actor_spec[:group_id] }

      # load_balancer: <load balancer name>
      elsif actor_spec.keys == [ :load_balancer ]
        lb = Chef::Resource::AwsLoadBalancer.get_aws_object(actor_spec.values.first, resource: new_resource)
        get_actors(vpc, lb)

      # security_group: <security group name>
      elsif actor_spec.keys == [ :security_group ]
        Chef::Resource::AwsSecurityGroup.get_aws_object(actor_spec[:security_group], resource: new_resource)

      else
        raise "Unable to reference security group with spec #{actor_spec}"
      end

    # If a load balancer is specified, grab it and then get its automatic security group
    when /^elb-[a-fA-F0-9]{8}$/, AWS::ELB::LoadBalancer, Chef::Resource::AwsLoadBalancer
      lb = Chef::Resource::AwsLoadBalancer.get_aws_object(actor_spec, resource: new_resource)
      get_actors(vpc, lb.source_security_group)

    # If a security group is specified, grab it
    when /^sg-[a-fA-F0-9]{8}$/, AWS::EC2::SecurityGroup, Chef::Resource::AwsSecurityGroup
      Chef::Resource::AwsSecurityGroup.get_aws_object(actor_spec, resource: new_resource)

    # If an IP addresses / CIDR are passed, return it verbatim; otherwise, assume it's the
    # name of a security group.
    when String
      begin
        IPAddr.new(actor_spec)
        # Add /32 to the end of raw IP addresses
        actor_spec =~ /\// ? actor_spec : "#{actor_spec}/32"
      rescue
        Chef::Resource::AwsSecurityGroup.get_aws_object(actor_spec, resource: new_resource)
      end

    else
      raise "Unexpected actor #{actor_spec} in rules list"
    end

    result = { user_id: result.owner_id, group_id: result.id } if result.is_a?(AWS::EC2::SecurityGroup)

    [ result ].flatten
  end

end

require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/resource/aws_vpc'
require 'retryable'

class Chef::Provider::AwsNetworkAcl < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::EC2ConvergeTags

  provides :aws_network_acl

  def action_create
    network_acl = super

    apply_rules(network_acl)
  end

  protected

  def create_aws_object
    converge_by "create network ACL #{new_resource.name} in #{region}" do
      options = {}
      options[:vpc_id] = new_resource.vpc if new_resource.vpc
      options = AWSResource.lookup_options(options, resource: new_resource)

      Chef::Log.debug("VPC: #{options[:vpc_id]}")

      network_acl = new_resource.driver.ec2_resource.create_network_acl(options)
      retry_with_backoff(::Aws::EC2::Errors::InvalidNetworkAclIDNotFound) do
        network_acl.create_tags({tags: [{key: "Name", value: new_resource.name}]})
      end
      network_acl
    end
  end

  def update_aws_object(network_acl)
    if !new_resource.vpc.nil?
      desired_vpc = Chef::Resource::AwsVpc.get_aws_object_id(new_resource.vpc, resource: new_resource)
      if desired_vpc != network_acl.vpc_id
        raise "Network ACL VPC cannot be changed after being created!  Desired VPC for #{new_resource.to_s} was #{new_resource.vpc} (#{desired_vpc}) and actual VPC is #{network_acl.vpc_id}"
      end
    end
  end

  def destroy_aws_object(network_acl)
    # TODO if purging, do we need to destory the linked subnets?
    converge_by "delete #{new_resource.to_s} in #{region}" do
      network_acl.delete
    end
  end

  private

  def apply_rules(network_acl)
    current_rules = network_acl.entries.map { |entry| entry_to_hash(entry) }
    inbound_rules = new_resource.inbound_rules
    outbound_rules = new_resource.outbound_rules
    # AWS requires a deny all rule at the end. Delete here so we don't
    # try to compare.
    current_rules.delete_if { |rule| rule[:rule_number] == 32767 }

    current_inbound_rules = current_rules.select { |rule| rule[:egress] == false }
    # If inbound_rules is nil, leave rules alone. If empty array, delete all.
    if inbound_rules
      desired_inbound_rules = inbound_rules.map { |rule| rule[:egress] = false; rule }
      compare_and_apply_rules(network_acl, :ingress, current_inbound_rules, desired_inbound_rules)
    end

    current_outbound_rules = current_rules.select { |rule| rule[:egress] == true }
    if outbound_rules
      desired_outbound_rules = outbound_rules.map { |rule| rule[:egress] = true; rule }
      compare_and_apply_rules(network_acl, :egress, current_outbound_rules, desired_outbound_rules)
    end
  end

  def compare_and_apply_rules(network_acl, direction, current_rules, desired_rules)
    replace_rules = []

    # Get the desired rules in a comparable state
    desired_rules.clone.each do |desired_rule|
      matching_rule = current_rules.select { |r| r[:rule_number] == desired_rule[:rule_number]}.first
      if matching_rule
        # Anything unhandled will be removed
        current_rules.delete(matching_rule)
        # Anything unhandled will be added
        desired_rules.delete(desired_rule)

        # Converting matching_rule [:rule_action] and [:port_range] to symbol & hash to match correctly with desired_rule
        matching_rule[:rule_action] = matching_rule[:rule_action].to_sym unless matching_rule[:rule_action].nil?
        matching_rule[:port_range] = matching_rule[:port_range].to_hash unless matching_rule[:port_range].nil?
        if matching_rule.merge(desired_rule) != matching_rule
          # Replace anything with a matching rule number but different attributes
          replace_rules << desired_rule
        end
      end
    end

    unless replace_rules.empty? && desired_rules.empty? && current_rules.empty?
      action_handler.report_progress "update network ACL #{new_resource.name} #{direction.to_s} rules"
      replace_rules(network_acl, replace_rules)
      add_rules(network_acl, desired_rules)
      remove_rules(network_acl, current_rules)
    end
  end

  def replace_rules(network_acl, rules)
    rules.each do |rule|
      action_handler.report_progress "  update #{rule_direction(rule)} rule #{rule[:rule_number]}"
      network_acl.replace_entry(rule)
    end
  end

  def add_rules(network_acl, rules)
    rules.each do |rule|
      action_handler.report_progress "  add #{rule_direction(rule)} rule #{rule[:rule_number]}"
      network_acl.create_entry(rule)
    end
  end

  def remove_rules(network_acl, rules)
    rules.each do |rule|
      action_handler.report_progress "  remove #{rule_direction(rule)} rule #{rule[:rule_number]}"
      network_acl.delete_entry(egress: rule[:egress], rule_number: rule[:rule_number])
    end
  end

  def rule_direction(rule)
    rule[:egress] == true ? 'egress' : 'ingress'
  end

  def entry_to_hash(entry)
    options = [
      :rule_number, :rule_action, :protocol, :cidr_block, :egress,
      :port_range, :icmp_type_code
    ]
    entry_hash = {}
    options.each { |option| entry_hash.merge!(option => entry.send(option.to_sym)) }
    entry_hash
  end
end

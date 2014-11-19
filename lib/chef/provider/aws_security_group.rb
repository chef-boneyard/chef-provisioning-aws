require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsSecurityGroup < Chef::Provider::AwsProvider

  action :create do
    if existing_sg == nil
      converge_by "Creating new SG #{new_resource.name} in #{new_resource.region_name}" do
        opts = {
            :description => new_resource.description,
            :vpc => nil
        }
        # Use VPC ID if provided, otherwise lookup VPC by name
        if new_resource.vpc_id
          opts[:vpc] = new_resource.vpc_id
        elsif new_resource.vpc_name
          existing_vpc = ec2.vpcs.with_tag('Name', new_resource.vpc_name).first
          Chef::Log.debug("Existing VPC: #{existing_vpc.inspect}")
          if existing_vpc
            opts[:vpc] = existing_vpc
          end
        end

        sg = ec2.security_groups.create(new_resource.name, opts)
        new_resource.security_group_id sg.group_id
        new_resource.save
      end
    end

    # Update rules
    apply_rules(existing_sg)
  end

  action :delete do
    if existing_vpc
      converge_by "Deleting SG #{new_resource.name} in #{new_resource.region_name}" do
        existing_sg.delete
      end
    end

    new_resource.delete
  end

  # TODO check existing rules and compare / remove?
  def apply_rules(security_group)
    # Incoming
    if new_resource.inbound_rules
      new_resource.inbound_rules.each do |rule|
        begin
          converge_by "Updating SG #{new_resource.name} in #{new_resource.region_name} to allow inbound #{rule[:protocol]}/#{rule[:ports]} from #{rule[:sources]}" do
            security_group.authorize_ingress(rule[:protocol], rule[:ports], *rule[:sources])
          end
        rescue AWS::EC2::Errors::InvalidPermission::Duplicate
          Chef::Log.debug 'Duplicate rule, ignoring.'
        end
      end
    end

    # Outgoing
    if new_resource.outbound_rules
      new_resource.outbound_rules.each do |rule|
        begin
          converge_by "Updating SG #{new_resource.name} in #{new_resource.region_name} to allow outbound #{rule[:protocol]}/#{rule[:ports]} to #{rule[:destinations]}" do
            security_group.authorize_egress( *rule[:destinations], :protocol => rule[:protocol], :ports => rule[:ports])
          end
        rescue AWS::EC2::Errors::InvalidPermission::Duplicate
          Chef::Log.debug 'Duplicate rule, ignoring.'
        end
      end
    end
  end

  def existing_sg
    @existing_sg ||= begin
      if id != nil
        ec2.security_groups[id]
      else
        nil
      end
    rescue
      nil
    end
  end

  def id
    new_resource.security_group_id
  end

end

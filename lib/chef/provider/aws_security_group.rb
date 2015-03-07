require 'chef/provider/aws_provider'
require 'date'
require 'ipaddr'

class Chef::Provider::AwsSecurityGroup < Chef::Provider::AwsProvider

  action :create do
    sg = aws_object
    if !sg
      converge_by "Creating new SG #{new_resource.name} in #{region}" do
        options = { description: new_resource.description }
        options[:vpc] = new_resource.vpc if new_resource.vpc
        options = managed_aws.lookup_options(options)
        Chef::Log.debug("VPC: #{options[:vpc]}")

        sg = aws_driver.ec2.security_groups.create(new_resource.name, options)
        save_managed_entry(id: sg.id)
      end
    end

    # Update rules
    apply_rules(sg)
  end

  action :delete do
    if aws_object
      converge_by "Deleting SG #{new_resource.name} in #{region}" do
        aws_object.delete
      end
    end

    delete_managed_entry
  end

  # TODO check existing rules and compare / remove?
  def apply_rules(security_group)
    # Incoming
    if new_resource.inbound_rules
      new_resource.inbound_rules.each do |rule|
        begin
          converge_by "Updating SG #{new_resource.name} in #{region} to allow inbound #{rule[:protocol]}/#{rule[:ports]} from #{rule[:sources]}" do
            sources = get_sources(rule[:sources])
            security_group.authorize_ingress(rule[:protocol], rule[:ports], *sources)
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
          converge_by "Updating SG #{new_resource.name} in #{region} to allow outbound #{rule[:protocol]}/#{rule[:ports]} to #{rule[:destinations]}" do
            security_group.authorize_egress( *get_sources(rule[:destinations]), :protocol => rule[:protocol], :ports => rule[:ports])
          end
        rescue AWS::EC2::Errors::InvalidPermission::Duplicate
          Chef::Log.debug 'Duplicate rule, ignoring.'
        end
      end
    end
  end

  # TODO need support for load balancers!
  def get_sources(sources)
    sources.map do |s|
      if s.is_a?(String)
        begin
          IPAddr.new(s)
          s
        rescue
          { group_id: managed_aws.get_aws_object(:security_group, s, required: true).id }
        end
      else
        s
      end
    end
  end

end

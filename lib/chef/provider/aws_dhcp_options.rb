require 'chef/provisioning/aws_driver/aws_provider'
require 'retryable'

class Chef::Provider::AwsDhcpOptions < Chef::Provisioning::AWSDriver::AWSProvider
  protected

  def create_aws_object
    options = desired_options
    if options.empty?
      options[:domain_name_servers] = "AmazonProvidedDNS"
    end

    converge_by "create new dhcp_options #{new_resource.name} in #{region}" do
      dhcp_options = new_resource.driver.ec2.dhcp_options.create(options)
      Retryable.retryable(:tries => 15, :sleep => 1, :on => AWS::EC2::Errors::InvalidDhcpOptionsID::NotFound) do
        dhcp_options.tags['Name'] = new_resource.name
      end
      dhcp_options
    end
  end

  def update_aws_object(dhcp_options)
    # Verify unmodifiable attributes of existing dhcp_options
    config = dhcp_options.configuration
    differing_options = desired_options.select { |name, value| config[name] != value }
    if !differing_options.empty?
      old_dhcp_options = dhcp_options
      # Report what we are trying to change ...
      action_handler.report_progress "update #{new_resource.to_s}"
      differing_options.each do |name, value|
        action_handler.report_progress "  set #{name} to #{value.inspect} (was #{config.has_key?(name) ? config[name].inspect : "not set"})"
      end

      # create new dhcp_options
      if action_handler.should_perform_actions
        dhcp_options = AWS.ec2(config: dhcp_options.config).dhcp_options.create(config.merge(desired_options))
      end
      action_handler.report_progress "create new dhcp_options #{dhcp_options.id} with new attributes in #{region}"

      # attach dhcp_options to existing vpcs
      old_dhcp_options.vpcs.each do |vpc|
        action_handler.perform_action "attach new dhcp_options #{dhcp_options.id} to vpc #{vpc.id}" do
          vpc.dhcp_options = dhcp_options
        end
      end

      # delete old dhcp_options
      action_handler.perform_action "delete old dhcp_options #{old_dhcp_options.id}" do
        old_dhcp_options.delete
      end

      [ :replaced_aws_object, dhcp_options ]
    end
  end

  def destroy_aws_object(dhcp_options)
    converge_by "delete dhcp_options #{new_resource.name} in #{region}" do
      dhcp_options.delete
    end
  end

  private

  def desired_options
    desired_options = {}
    %w(domain_name domain_name_servers ntp_servers netbios_name_servers netbios_node_type).each do |attr|
      attr = attr.to_sym
      value = new_resource.public_send(attr)
      desired_options[attr] = value unless value.nil?
    end
    Chef::Provisioning::AWSDriver::AWSResource.lookup_options(desired_options, resource: new_resource)
  end
end

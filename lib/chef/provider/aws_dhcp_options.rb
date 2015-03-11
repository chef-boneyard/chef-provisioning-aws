require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsDhcpOptions < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    dhcp_options = new_resource.aws_object
    if dhcp_options
      update_dhcp_options(dhcp_options)
    else
      dhcp_options = create_dhcp_options
    end
  end

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      converge_by "delete dhcp_options #{new_resource.name} in #{region}" do
        aws_object.delete
      end
    end

    new_resource.delete_managed_entry(action_handler)
  end

  private

  def create_dhcp_options
    options = desired_options
    if options.empty?
      options[:domain_name_servers] = "AmazonProvidedDNS"
    end

    dhcp_options = nil
    converge_by "create new dhcp_options #{new_resource.name} in #{region}" do
      dhcp_options = driver.ec2.dhcp_options.create(options)
      dhcp_options.tags['Name'] = new_resource.name
    end

    new_resource.save_managed_entry(dhcp_options, action_handler)

    dhcp_options
  end

  #
  # Because DHCP options are non-updateable, updating them requires creating a new
  # set and updating all VPCs.
  #
  def update_dhcp_options(dhcp_options)
    # Verify unmodifiable attributes of existing dhcp_options
    config = dhcp_options.configuration
    if desired_options.any? { |name, value| config[name] != value }
      old_dhcp_options = dhcp_options
      converge_by "update dhcp_options #{new_resource.name} to #{dhcp_options.id} (was #{old_dhcp_options.id}) and updated VPCs in #{region}" do
        # create new dhcp_options
        dhcp_options = driver.ec2.dhcp_options.create(config.merge(desired_options))
        action_handler.report_progress "create new dhcp_options #{dhcp_options.id} in #{region}"
        # attach dhcp_options to existing vpcs
        old_dhcp_options.vpcs.each do |vpc|
          vpc.dhcp_options = dhcp_options
          action_handler.report_progress "attach dhcp_options #{dhcp_options.id} to vpc #{vpc.id}"
        end
        # delete old dhcp_options
        old_dhcp_options.delete
        action_handler.report_progress "delete old dhcp_options #{old_dhcp_options.id}"
      end
      new_resource.save_managed_entry(dhcp_options, action_handler)
    end
  end

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

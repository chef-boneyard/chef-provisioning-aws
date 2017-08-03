require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsDhcpOptions < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::EC2ConvergeTags

  provides :aws_dhcp_options

  protected

  def create_aws_object
    options = desired_options
    if options.empty?
      options[:domain_name_servers] = "AmazonProvidedDNS"
    end

    converge_by "create DHCP options #{new_resource.name} in #{region}" do
      create_dhcp_options options
    end
  end

  def create_dhcp_options options
    options = options.map{|k,v| {key: k.to_s.gsub('_', '-'), values: Array(v).map(&:to_s)}}
    ec2_resource = ::Aws::EC2::Resource.new(new_resource.driver.ec2)
    dhcp_options = ec2_resource.create_dhcp_options({dhcp_configurations: options})
    retry_with_backoff(::Aws::EC2::Errors::InvalidDhcpOptionIDNotFound) do
      dhcp_options.create_tags({tags: [{key: "Name", value: new_resource.name}]})
    end
    dhcp_options
  end

  def update_aws_object(dhcp_options)
    # Verify unmodifiable attributes of existing dhcp_options
    config = dhcp_options.data.to_h[:dhcp_configurations].map{|a|{a[:key].gsub('-', '_').to_sym => a[:values].map{|k|k[:value]} }}.reduce Hash.new, :merge
    differing_options = desired_options.select { |name, value| config[name] != Array(value).map(&:to_s) }
    if !differing_options.empty?
      old_dhcp_options = dhcp_options
      # Report what we are trying to change ...
      action_handler.report_progress "update #{new_resource.to_s}"
      differing_options.each do |name, value|
        action_handler.report_progress "  set #{name} to #{value.inspect} (was #{config.has_key?(name) ? config[name].inspect : "not set"})"
      end

      # create new dhcp_options
      if action_handler.should_perform_actions
        dhcp_options = create_dhcp_options(config.merge(desired_options))
      end
      action_handler.report_progress "create DHCP options #{dhcp_options.id} with new attributes in #{region}"

      # attach dhcp_options to existing vpcs
      ec2_resource = ::Aws::EC2::Resource.new(new_resource.driver.ec2)
      ec2_resource.vpcs.each do |vpc|
        if vpc.dhcp_options_id == old_dhcp_options.id
          dhcp_options.associate_with_vpc({
            dry_run: false,
            vpc_id: vpc.id, # required
          })
        end
      end

      # delete old dhcp_options
      action_handler.perform_action "delete DHCP options #{old_dhcp_options.id}" do
        old_dhcp_options.delete
      end

      [ :replaced_aws_object, dhcp_options ]
    end
  end

  def destroy_aws_object(dhcp_options)
    converge_by "delete DHCP options #{new_resource.name} in #{region}" do
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

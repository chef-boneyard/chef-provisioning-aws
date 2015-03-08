require 'chef/provisioning/aws_driver/aws_resource_with_entry'
require 'ipaddr'

class Chef::Resource::AwsEipAddress < Chef::Provisioning::AWSDriver::AWSResource
  aws_type AWS::EC2::IpAddress, :ip_address, managed_entry_id_name: 'public_ip', backcompat_data_bag_name: 'eip_addresses'

  actions :delete, :nothing, :associate, :disassociate
  default_action :associate

  attribute :name, kind_of: String, name_attribute: true

  attribute :associate_to_vpc, kind_of: [TrueClass, FalseClass], default: false
  attribute :machine,          kind_of: String

  #
  # Desired public IP address to associate with this Chef resource.
  #
  # Defaults to 'name' if name is an IP address.
  #
  # If the IP address is already allocated to your account, Chef will ensure it is
  # linked to the current .  Thus, this is a way to associate an existing AWS IP
  # with Chef:
  #
  # ```ruby
  # aws_eip_address 'frontend_ip' do
  #   public_ip '205.32.21.0'
  # end
  # ```
  #
  attribute :public_ip, kind_of: String, aws_id_attribute: true, coerce { |v| IPAddr.new(v); v },
    default {
      begin
        IPAddr.new(name)
        name
      rescue
      end
    }

  protected

  def get_aws_object(driver, id)
    driver.ec2.elastic_ips[public_ip]
  end
end

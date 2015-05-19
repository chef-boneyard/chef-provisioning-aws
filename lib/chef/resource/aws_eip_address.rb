require 'chef/provisioning/aws_driver/aws_resource_with_entry'
require 'ipaddr'

class Chef::Resource::AwsEipAddress < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::EC2::ElasticIp, option_names: [ :public_ip ], id: :public_ip, managed_entry_id_name: 'public_ip', backcompat_data_bag_name: 'eip_addresses'

  attribute :name, kind_of: String, name_attribute: true

  # guh - every other AWSResourceWithEntry accepts tags EXCEPT this one
  undef_method(:aws_tags)

  # TODO network interface
  attribute :machine,          kind_of: [String, FalseClass]
  attribute :associate_to_vpc, kind_of: [TrueClass, FalseClass]

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
  attribute :public_ip, kind_of: String, aws_id_attribute: true, coerce: proc { |v| IPAddr.new(v); v },
    lazy_default: proc {
      begin
        IPAddr.new(name)
        name
      rescue
      end
    }

  def aws_object
    driver, public_ip = get_driver_and_id
    result = driver.ec2.elastic_ips[public_ip] if public_ip
    result && result.exists? ? result : nil
  end

  def action(*args)
    # Backcompat for associate and disassociate
    if args == [ :associate ]
      super(:create)
    elsif args == [ :disassociate ]
      machine false
      super(:create)
    else
      super
    end
  end
end

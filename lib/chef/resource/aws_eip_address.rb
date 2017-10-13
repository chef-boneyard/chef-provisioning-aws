require 'chef/provisioning/aws_driver/aws_resource_with_entry'

class Chef::Resource::AwsEipAddress < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type ::Aws::OpsWorks::Types::ElasticIp, option_names: [ :public_ip ], id: :public_ip, managed_entry_id_name: 'public_ip', backcompat_data_bag_name: 'eip_addresses'

  attribute :name, kind_of: String, name_attribute: true

  # TODO network interface
  attribute :machine,          kind_of: [String, FalseClass]
  attribute :associate_to_vpc, kind_of: [TrueClass, FalseClass]

  # Like other aws_id_attributes, this is read-only - you cannot provide it and expect
  # aws to honor it
  attribute :public_ip, kind_of: String, aws_id_attribute: true,
                        default: lazy { name =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/ ? name : nil }

  def aws_object
    driver, public_ip = get_driver_and_id
    result = driver.ec2.describe_addresses.addresses.find { |b| b.public_ip == public_ip }
    result && !result.empty? ? result : nil
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

require 'chef/provisioning/aws_driver/aws_resource_with_entry'
require 'chef/resource/aws_instance'

class Chef::Resource::AwsEbsVolume < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::EC2::Volume, backcompat_data_bag_name: 'ebs_volumes'

  attribute :name,    kind_of: String, name_attribute: true

  attribute :machine,           kind_of: [ String, FalseClass, AwsInstance, ::Aws::EC2::Instance, ::Aws::EC2::Instance ]

  attribute :availability_zone, kind_of: String, default: 'a'
  attribute :size,              kind_of: Integer, default: 8
  attribute :snapshot,          kind_of: String

  attribute :iops,              kind_of: Integer
  attribute :volume_type,       kind_of: String
  attribute :encrypted,         kind_of: [ TrueClass, FalseClass ]
  attribute :device,            kind_of: String

  attribute :volume_id,         kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^vol-(?:[a-f0-9]{8}|[a-f0-9]{17})$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2_resource.volume(id) if id
    result && exists?(result) && ![:deleted, :deleting].include?(result.state) ? result : nil
  end
  
  def exists?(result)
    return true if result.data
  rescue ::Aws::EC2::Errors::InvalidVolumeNotFound
    return false
  end
end

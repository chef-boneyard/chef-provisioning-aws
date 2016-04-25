require 'chef/provisioning/aws_driver/aws_resource_with_entry'
require 'chef/provisioning/aws_driver/aws_taggable'

class Chef::Resource::AwsImage < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::EC2::Image,
               managed_entry_type: :machine_image,
               managed_entry_id_name: 'image_id'

  attribute :name, kind_of: String, name_attribute: true

  attribute :image_id, kind_of: String, aws_id_attribute: true, default: lazy {
    name =~ /^ami-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2_resource.image(id) if id
    result && result.exists? ? result : nil
  end
end

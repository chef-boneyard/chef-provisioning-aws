require 'chef/provisioning/aws_driver/aws_resource_with_entry'

class Chef::Resource::AwsImage < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::EC2::Image,
               managed_entry_type:    :machine_image,
               managed_entry_id_name: 'image_id'

  attribute :name, kind_of: String,  name_attribute: true

  attribute :image_id, kind_of: String, aws_id_attribute: true, lazy_default: proc {
    name =~ /^ami-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2.images[id] if id
    result && result.exists? ? result : nil
  end
end

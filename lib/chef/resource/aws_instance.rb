require 'chef/provisioning/aws_driver/aws_resource_with_entry'

class Chef::Resource::AwsInstance < Chef::Provisioning::AWSDriver::AWSResourceWithEntry
  aws_sdk_type AWS::EC2::Instance,
    managed_entry_type: :machine,
    managed_entry_id_name: 'instance_id'

  attribute :name, kind_of: String, name_attribute: true

  attribute :instance_id, kind_of: String, aws_id_attribute: true, lazy_default: proc {
    name =~ /^i-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    driver, id = get_driver_and_id
    result = driver.ec2.instances[id] if id
    result && result.exists? ? result : nil
  end
end

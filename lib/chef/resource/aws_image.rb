require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsImage < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::EC2::Image, load_provider: false

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, kind_of: String,  name_attribute: true

  attribute :image_id, kind_of: String, aws_id_attribute: true, lazy_default: proc {
    name =~ /^ami-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    if image_id
      result = driver.ec2.images[image_id]
    else
      result = driver.ec2.images.filter('name', name)
    end
    result && result.exists? ? result : nil
  end
end

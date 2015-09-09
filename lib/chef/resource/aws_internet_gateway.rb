require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsInternetGateway < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type AWS::EC2::InternetGateway, load_provider: false, id: :id

  attribute :name, kind_of: String, name_attribute: true

  attribute :internet_gateway_id, kind_of: String, aws_id_attribute: true, lazy_default: proc {
    name =~ /^igw-[a-f0-9]{8}$/ ? name : nil
  }

  def aws_object
    result = driver.ec2.internet_gateways[internet_gateway_id]
    result && result.exists? ? result : nil
  end
end

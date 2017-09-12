require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsServerCertificate < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type ::Aws::IAM::ServerCertificate

  attribute :name, kind_of: String, name_attribute: true

  attribute :certificate_body, kind_of: String
  attribute :certificate_chain, kind_of: String
  attribute :private_key, kind_of: String

  def aws_object
    begin
      cert = ::Aws::IAM::ServerCertificate.new(name,{client: driver.iam} )
      cert.data
      cert
    rescue ::Aws::IAM::Errors::NoSuchEntity
      nil
    end
  end
end

require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsServerCertificate < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::IAM::ServerCertificate

  attribute :name, kind_of: String, name_attribute: true

  attribute :certificate_body, kind_of: String
  attribute :private_key, kind_of: String

  def aws_object
    begin
      cert = driver.iam.server_certificates[name]
      # this will trigger a AWS::IAM::Errors::NoSuchEntity if the cert does not exist
      cert.arn
      cert
    rescue AWS::IAM::Errors::NoSuchEntity
      nil
    end
  end
end

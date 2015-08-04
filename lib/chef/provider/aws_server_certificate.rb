require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsServerCertificate < Chef::Provisioning::AWSDriver::AWSProvider
  def update_aws_object(certificate)
    Chef::Log.warn("aws_server_certificate does not support modifying an existing certificate")
  end

  def create_aws_object
    converge_by "Create new Server Certificate #{new_resource.name}" do
      new_resource.driver.iam.server_certificates.upload(:name => new_resource.name,
                                                         :certificate_body => new_resource.certificate_body,
                                                         :private_key => new_resource.private_key)
    end
  end

  def destroy_aws_object(certificate)
    converge_by "Deleting Server Certificate #{new_resource.name}" do
      certificate.delete
    end
  end
end
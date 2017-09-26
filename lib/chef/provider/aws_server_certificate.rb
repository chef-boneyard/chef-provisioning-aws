require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsServerCertificate < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_server_certificate

  def update_aws_object(certificate)
    Chef::Log.warn("aws_server_certificate does not support modifying an existing certificate")
  end

  def create_aws_object
    converge_by "create server certificate #{new_resource.name}" do
      opts = {
        :server_certificate_name => new_resource.name,
        :certificate_body => new_resource.certificate_body,
        :private_key => new_resource.private_key      }
      opts[:certificate_chain] = new_resource.certificate_chain if new_resource.certificate_chain
      new_resource.driver.iam.upload_server_certificate(**opts)
    end
  end

  def destroy_aws_object(certificate)
    converge_by "delete server certificate #{new_resource.name}" do
      certificate.delete
    end
  end
end

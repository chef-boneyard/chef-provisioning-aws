require 'chef/provisioning/aws_driver/aws_provider'
require 'date'

class Chef::Provider::AwsSnsTopic < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    aws_object = new_resource.aws_object
    if !aws_object
      converge_by "Creating new SNS topic #{new_resource.name} in #{region}" do
        driver.sns.topics.create(new_resource.name)
      end
    end
  end

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      converge_by "Deleting SNS topic #{new_resource.name} in #{region}" do
        aws_object.delete
      end
    end
  end

end

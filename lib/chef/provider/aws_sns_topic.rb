require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsSnsTopic < Chef::Provider::AwsProvider

  action :create do
    if !current_aws_object
      converge_by "Creating new SNS topic #{new_resource.name} in #{region}" do
        new_driver.sns.topics.create(new_resource.name)
      end
    end
  end

  action :delete do
    if current_aws_object
      converge_by "Deleting SNS topic #{new_resource.name} in #{region}" do
        current_aws_object.delete
      end
    end
  end

end

require 'chef/resource/aws_resource'

class Chef::Resource::AwsSqsQueue < Chef::Resource::AwsResource
  self.resource_name = 'aws_sqs_queue'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name,    kind_of: String, name_attribute: true
  attribute :options, kind_of: Hash

  # Main code is in lib/chef/provisioning/aws_driver/managed_aws.rb
  def aws_object
    get_aws_object(:sqs_queue, name)
  end
end

require 'chef/resource/aws_resource'

class Chef::Resource::AwsS3Bucket < Chef::Resource::AwsResource
  self.resource_name = 'aws_s3_bucket'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :options, :kind_of => Hash, :default => {}
  attribute :enable_website_hosting, :kind_of => [TrueClass, FalseClass], :default => false
  attribute :website_options, :kind_of => Hash

  # Main code is in lib/chef/provisioning/aws_driver/managed_aws.rb
  def aws_object
    get_aws_object(:aws_s3_bucket, name)
  end
end

require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsS3Bucket < Chef::Resource::AwsResource
  self.resource_name = 'aws_s3_bucket'
  self.databag_name = 's3_buckets'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :bucket_name, :kind_of => String
  attribute :enable_website_hosting, :kind_of => [TrueClass, FalseClass], :default => false
  attribute :website_options, :kind_of => Hash

  stored_attribute :endpoint

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

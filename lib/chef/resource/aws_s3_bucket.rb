require 'chef/resource/aws_resource'
require 'chef_metal_aws'

class Chef::Resource::AwsS3Bucket < Chef::Resource::AwsResource
  self.resource_name = 'aws_s3_bucket'
  self.databag_name = 's3_buckets'

  actions :create, :delete, :nothing
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :bucket_name, :kind_of => String

  def initialize(*args)
    super
  end

  def after_created
    super
  end
end

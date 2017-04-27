require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsS3Bucket < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::S3::Bucket, id: :name

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :options, :kind_of => Hash, :default => {}
  attribute :enable_website_hosting, :kind_of => [TrueClass, FalseClass], :default => false
  attribute :website_options, :kind_of => Hash, :default => {}
  attribute :recursive_delete, :kind_of => [TrueClass, FalseClass], :default => false

  def aws_object
    resource = ::Aws::S3::Resource.new(driver.s3_client)
    result = resource.buckets.find{|b| b.name==name}
    result && result.exists? ? result : nil
  end
end

require 'chef/provisioning/aws_driver/aws_resource'

class Chef::Resource::AwsS3Bucket < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::S3::Bucket, id: :name

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :options, :kind_of => Hash, :default => {}
  attribute :enable_website_hosting, :kind_of => [TrueClass, FalseClass], :default => false
  attribute :website_options, :kind_of => Hash, :default => {}

  def aws_object
    result = driver.s3.buckets[name]
    result && result.exists? ? result : nil
  end
end

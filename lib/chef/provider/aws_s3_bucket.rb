require 'chef/provisioning/aws_driver/aws_provider'
require 'date'

class Chef::Provider::AwsS3Bucket < Chef::Provisioning::AWSDriver::AWSProvider
  def action_create
    bucket = super

    if new_resource.enable_website_hosting
      if !bucket.website?
        converge_by "Enabling website configuration for bucket #{new_resource.name}" do
          bucket.website_configuration = AWS::S3::WebsiteConfiguration.new(
            new_resource.website_options)
        end
      elsif modifies_website_configuration?(bucket)
        converge_by "Reconfiguring website configuration for bucket #{new_resource.name} to #{new_resource.website_options}" do
          bucket.website_configuration = AWS::S3::WebsiteConfiguration.new(
            new_resource.website_options)
        end
      end
    else
      if bucket.website?
        converge_by "Disabling website configuration for bucket #{new_resource.name}" do
          bucket.website_configuration = nil
        end
      end
    end
  end

  protected

  def create_aws_object
    converge_by "create new S3 bucket #{new_resource.name}" do
      bucket = new_resource.driver.s3.buckets.create(new_resource.name)
      bucket.tags['Name'] = new_resource.name
      bucket
    end
  end

  def update_aws_object(bucket)
  end

  def destroy_aws_object(bucket)
    converge_by "delete S3 bucket #{new_resource.name}" do
      bucket.delete
    end
  end

  private

  def modifies_website_configuration?(aws_object)
    # This is incomplete, routing rules have many optional values, so its
    # possible aws will put in default values for those which won't be in
    # the requested config.
    new_web_config = new_resource.website_options || {}

    current_web_config = (aws_object.website_configuration || {}).to_hash

    (current_web_config[:index_document] != new_web_config.fetch(:index_document, {}) ||
    current_web_config[:error_document] != new_web_config.fetch(:error_document, {}) ||
    current_web_config[:routing_rules] != new_web_config.fetch(:routing_rules, []))
  end

  def s3_website_endpoint_region
    # ¯\_(ツ)_/¯
    case aws_object.location_constraint
    when nil, 'US'
      'us-east-1'
    when 'EU'
      'eu-west-1'
    else
      aws_object.location_constraint
    end
  end
end

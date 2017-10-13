require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/tagging_strategy/s3'
require 'date'

class Chef::Provider::AwsS3Bucket < Chef::Provisioning::AWSDriver::AWSProvider

  def aws_tagger
    @aws_tagger ||= begin
      s3_strategy = Chef::Provisioning::AWSDriver::TaggingStrategy::S3.new(
        # I'm using the V2 client here because it has much better support for tags
        new_resource.driver.s3_client,
        new_resource.name,
        new_resource.aws_tags
      )
      Chef::Provisioning::AWSDriver::AWSTagger.new(s3_strategy, action_handler)
    end
  end

  def converge_tags
    aws_tagger.converge_tags
  end

  provides :aws_s3_bucket

  def action_create
    bucket = super

    if new_resource.enable_website_hosting
     if !website_exist?(new_resource,bucket)
        converge_by "enable website configuration for bucket #{new_resource.name}" do
          create_website(bucket,new_resource )
        end
      elsif modifies_website_configuration?(bucket)
        converge_by "reconfigure website configuration for bucket #{new_resource.name} to #{new_resource.website_options}" do
          create_website(bucket,new_resource )
        end
      end
    else
      if website_exist?(new_resource,bucket)
        converge_by "disable website configuration for bucket #{new_resource.name}" do
          new_resource.driver.s3_client.delete_bucket_website(bucket: new_resource.name)
        end
      end
    end
  end

  protected

  def create_aws_object
    converge_by "create S3 bucket #{new_resource.name}" do
      options = new_resource.options.merge({bucket: new_resource.name})
      new_resource.driver.s3_client.create_bucket(options)
      # S3 buckets already have a top level name property so they don't need
      # a 'Name' tag
    end
  end

  def update_aws_object(bucket)
  end

  def destroy_aws_object(bucket)
    if purging
      new_resource.recursive_delete(true)
    end
    converge_by "delete S3 bucket #{new_resource.name}" do
      if new_resource.recursive_delete
        bucket.delete!
      else
        bucket.delete
      end
    end
  end

  private

  def website_exist?(new_resource,bucket)
    return true if new_resource.driver.s3_client.get_bucket_website(bucket: new_resource.name) 
  rescue Aws::S3::Errors::NoSuchWebsiteConfiguration
    return false
  end

  def create_website(bucket,new_resource )
    website_configuration = Aws::S3::Types::WebsiteConfiguration.new(
            new_resource.website_options)
    s3_client = new_resource.driver.s3_client
    s3_client.put_bucket_website( bucket: new_resource.name,  website_configuration:website_configuration)
  end

  def modifies_website_configuration?(aws_object)
    # This is incomplete, routing rules have many optional values, so its
    # possible aws will put in default values for those which won't be in
    # the requested config.
    new_web_config = new_resource.website_options || {}

    current_web_config = (aws_object.website.data || {}).to_hash

    (current_web_config[:index_document] != new_web_config.fetch(:index_document, nil) ||
    current_web_config[:error_document] != new_web_config.fetch(:error_document, nil) ||
    current_web_config[:routing_rules] != new_web_config.fetch(:routing_rules, nil))
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

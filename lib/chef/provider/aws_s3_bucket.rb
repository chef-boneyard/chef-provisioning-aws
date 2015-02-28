require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsS3Bucket < Chef::Provider::AwsProvider
  action :create do
    bucket = current_aws_object
    if !bucket
      converge_by "Creating new S3 bucket #{new_resource.name}" do
        bucket = new_driver.s3.buckets.create(new_resource.name)
        bucket.tags['Name'] = new_resource.name
      end
    end

    if modifies_website_configuration?
      if new_resource.enable_website_hosting
        converge_by "Setting website configuration for bucket #{new_resource.name}" do
          bucket.website_configuration = AWS::S3::WebsiteConfiguration.new(
            new_resource.website_options)
        end
      else
        converge_by "Disabling website configuration for bucket #{new_resource.name}" do
          bucket.website_configuration = nil
        end
      end
    end
  end

  action :delete do
    if current_aws_object
      converge_by "Deleting S3 bucket #{new_resource.name}" do
        current_aws_object.delete
      end
    end
  end

  def current_aws_object
    result = super
    if result.exists?
      result
    else
      nil
    end
  end

  def modifies_website_configuration?
    # This is incomplete, routing rules have many optional values, so its
    # possible aws will put in default values for those which won't be in
    # the requested config.
    new_web_config = new_resource.website_options
    current_web_config = current_website_configuration

    !!current_aws_object.website_configuration != new_resource.enable_website_hosting ||
      (current_web_config[:index_document] != new_web_config.fetch(:index_document, {}) ||
      current_web_config[:error_document] != new_web_config.fetch(:error_document, {}) ||
      current_web_config[:routing_rules] != new_web_config.fetch(:routing_rules, []))
  end

  def current_website_configuration
    if current_aws_object.website_configuration
      current_aws_object.website_configuration.to_hash
    else
      {}
    end
  end

  def s3_website_endpoint_region
    # ¯\_(ツ)_/¯
    case current_aws_object.location_constraint
    when nil, 'US'
      'us-east-1'
    when 'EU'
      'eu-west-1'
    else
      current_aws_object.location_constraint
    end
  end
end

require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsS3Bucket < Chef::Provider::AwsProvider
  action :create do
    if existing_bucket == nil
      converge_by "Creating new S3 bucket #{fqn}" do
        bucket = new_driver.s3.buckets.create(fqn)
        bucket.tags['Name'] = new_resource.name
      end
    end
    
    if modifies_website_configuration?
      if new_resource.enable_website_hosting
        converge_by "Setting website configuration for bucket #{fqn}" do
          existing_bucket.website_configuration = AWS::S3::WebsiteConfiguration.new(
            new_resource.website_options)
        end
      else
        converge_by "Disabling website configuration for bucket #{fqn}" do
          existing_bucket.website_configuration = nil
        end
      end
    end
    new_resource.endpoint "#{fqn}.s3-website-#{s3_website_endpoint_region}.amazonaws.com"
    new_resource.save
  end

  action :delete do
    if existing_bucket
      converge_by "Deleting S3 bucket #{fqn}" do
        existing_bucket.delete
      end
    end

    new_resource.delete
  end

  def existing_bucket
    Chef::Log.debug("Checking for S3 bucket #{fqn}")
    @existing_bucket ||= new_driver.s3.buckets[fqn] if new_driver.s3.buckets[fqn].exists?
  end

  def modifies_website_configuration?
    # This is incomplete, routing rules have many optional values, so its
    # possible aws will put in default values for those which won't be in
    # the requested config.
    new_web_config = new_resource.website_options
    current_web_config = current_website_configuration

    !!existing_bucket.website_configuration != new_resource.enable_website_hosting || 
      (current_web_config[:index_document] != new_web_config.fetch(:index_document, {}) ||
      current_web_config[:error_document] != new_web_config.fetch(:error_document, {}) ||
      current_web_config[:routing_rules] != new_web_config.fetch(:routing_rules, []))
  end

  def current_website_configuration
    if existing_bucket.website_configuration
      existing_bucket.website_configuration.to_hash
    else
      {}
    end
  end

  def s3_website_endpoint_region
    # ¯\_(ツ)_/¯
    case existing_bucket.location_constraint
    when nil, 'US'
      'us-east-1'
    when 'EU'
      'eu-west-1'
    else
      existing_bucket.location_constraint
    end
  end

  # Fully qualified bucket name (i.e resource_region unless otherwise specified)
  def id
    new_resource.bucket_name || new_resource.name
  end
end

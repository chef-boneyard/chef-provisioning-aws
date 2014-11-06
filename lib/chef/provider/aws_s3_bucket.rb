require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsS3Bucket < Chef::Provider::AwsProvider
  action :create do
    if existing_bucket == nil
      converge_by "Creating new S3 bucket #{fqn}" do
        bucket = s3.buckets.create(fqn)
        bucket.tags['Name'] = new_resource.name
        if new_resource.enable_website_hosting
          bucket.website_configuration = AWS::S3::WebsiteConfiguration.new(
            new_resource.website_options)
        end
      end
    elsif requires_modification?
      converge_by "Modifying S3 Bucket #{fqn}" do
        if existing_bucket.website_configuration == nil && new_resource.enable_website_hosting || 
          existing_bucket.website_configuration != nil && new_resource.enable_website_hosting
          existing_bucket.website_configuration = AWS::S3::WebsiteConfiguration.new(
            new_resource.website_options)
        else
          existing_bucket.remove_website_configuration
        end
      end
    end

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
    @existing_bucket ||= s3.buckets[fqn] if s3.buckets[fqn].exists?
  end

  def requires_modification?
    if existing_bucket.website_configuration == nil
      new_resource.enable_website_hosting
    else
      !new_resource.enable_website_hosting ||
        !compare_website_configuration
    end
  end

  def compare_website_configuration
    # This is incomplete, routing rules have many optional values, so its
    # possible aws will put in default values for those which won't be in
    # the requested config.
    new_web_config = new_resource.website_options
    current_web_config = existing_bucket.website_configuration.to_hash

    current_web_config[:index_document] == new_web_config.fetch(:index_document, {}) &&
      current_web_config[:error_document] == new_web_config.fetch(:error_document, {}) &&
      current_web_config[:routing_rules] == new_web_config.fetch(:routing_rules, [])
  end

  # Fully qualified bucket name (i.e resource_region unless otherwise specified)
  def id
    new_resource.bucket_name || new_resource.name
  end
end

require 'chef/provisioning/aws_driver/aws_provider'
require 'date'

class Chef::Provider::AwsS3Bucket < Chef::Provisioning::AWSDriver::AWSProvider
  action :create do
    aws_object = new_resource.aws_object
    if aws_object.nil?
      converge_by "Creating new S3 bucket #{new_resource.name}" do
        aws_object = driver.s3.buckets.create(new_resource.name)
        aws_object.tags['Name'] = new_resource.name
      end
    end

    if new_resource.enable_website_hosting
      if !aws_object.website?
        converge_by "Enabling website configuration for bucket #{new_resource.name}" do
          aws_object.website_configuration = AWS::S3::WebsiteConfiguration.new(
            new_resource.website_options)
        end
      elsif modifies_website_configuration(aws_object)
        converge_by "Reconfiguring website configuration for bucket #{new_resource.name} to #{new_resource.website_options}" do
          aws_object.website_configuration = AWS::S3::WebsiteConfiguration.new(
            new_resource.website_options)
        end
      end
    else
      if aws_object.website?
        converge_by "Disabling website configuration for bucket #{new_resource.name}" do
          aws_object.website_configuration = nil
        end
      end
    end
  end

  action :delete do
    aws_object = new_resource.aws_object
    if aws_object
      converge_by "Deleting S3 bucket #{new_resource.name}" do
        aws_object.delete
      end
    end
  end

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

require 'chef/provider/aws_provider'
require 'date'

class Chef::Provider::AwsS3Bucket < Chef::Provider::AwsProvider
  action :create do
    if existing_bucket == nil
      converge_by "Creating new S3 bucket #{fqn}" do
        bucket = s3.buckets.create(fqn)
        bucket.tags['Name'] = new_resource.name
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

  # Fully qualified bucket name (i.e resource_region unless otherwise specified)
  def id
    new_resource.bucket_name
  end

  def fqn
    super.gsub('_', '-')
  end

end

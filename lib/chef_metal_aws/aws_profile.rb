class AwsProfile

  # Order of operations:
  # compute_options[:aws_access_key_id] / compute_options[:aws_secret_access_key] / compute_options[:aws_security_token] / compute_options[:region]
  # compute_options[:aws_profile]
  # ENV['AWS_ACCESS_KEY_ID'] / ENV['AWS_SECRET_ACCESS_KEY'] / ENV['AWS_SECURITY_TOKEN'] / ENV['AWS_REGION']
  # ENV['AWS_PROFILE']
  # ENV['DEFAULT_PROFILE']
  # 'default'
  def initialize(driver_options, aws_account_id)
    aws_credentials = get_aws_credentials(driver_options)
    compute_options = driver_options[:compute_options] || {}

    aws_profile = if compute_options[:aws_access_key_id]
                    Chef::Log.debug('Using AWS driver access key options')
                    {
                        :aws_access_key_id => compute_options[:aws_access_key_id],
                        :aws_secret_access_key => compute_options[:aws_secret_access_key],
                        :aws_security_token => compute_options[:aws_session_token],
                        :region => compute_options[:region]
                    }
                  elsif driver_options[:aws_profile]
                    Chef::Log.debug("Using AWS profile #{driver_options[:aws_profile]}")
                    aws_credentials[driver_options[:aws_profile]]
                  elsif ENV['AWS_ACCESS_KEY_ID'] || ENV['AWS_ACCESS_KEY']
                    Chef::Log.debug('Using AWS environment variable access keys')
                    {
                        :aws_access_key_id => ENV['AWS_ACCESS_KEY_ID'] || ENV['AWS_ACCESS_KEY'],
                        :aws_secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'] || ENV['AWS_SECRET_KEY'],
                        :aws_security_token => ENV['AWS_SECURITY_TOKEN'],
                        :region => ENV['AWS_REGION']
                    }
                  elsif ENV['AWS_PROFILE']
                    Chef::Log.debug("Using AWS profile #{ENV['AWS_PROFILE']} from AWS_PROFILE environment variable")
                    aws_credentials[ENV['AWS_PROFILE']]
                  else
                    Chef::Log.debug('Using AWS default profile')
                    aws_credentials.default
                  end
    # Endpoint configuration
    if compute_options[:ec2_endpoint]
      aws_profile[:ec2_endpoint] = compute_options[:ec2_endpoint]
    elsif ENV['EC2_URL']
      aws_profile[:ec2_endpoint] = ENV['EC2_URL']
    end
    if compute_options[:iam_endpoint]
      aws_profile[:iam_endpoint] = compute_options[:iam_endpoint]
    elsif ENV['AWS_IAM_URL']
      aws_profile[:iam_endpoint] = ENV['AWS_IAM_URL']
    else
      aws_profile[:iam_endpoint] = 'https://iam.amazonaws.com/'
    end

    # Merge in account info for profile
    if aws_profile
      aws_profile = aws_profile.merge(aws_account_info_for(aws_profile))
    end

    # If no profile is found (or the profile is not the right account), search
    # for a profile that matches the given account ID
    if aws_account_id && (!aws_profile || aws_profile[:aws_account_id] != aws_account_id)
      aws_profile = find_aws_profile_for_account_id(aws_credentials, aws_account_id)
    end

    unless aws_profile
      raise 'No AWS profile specified!  Are you missing something in the Chef config or ~/.aws/config?'
    end

    aws_profile.delete_if { |_, value| value.nil? }
    aws_profile
  end

end
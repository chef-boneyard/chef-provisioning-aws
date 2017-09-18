require "aws-sdk"
require "aws-sdk-core/credentials"
require "aws-sdk-core/shared_credentials"
require "aws-sdk-core/instance_profile_credentials"
require "aws-sdk-core/assume_role_credentials"

class Chef
module Provisioning
module AWSDriver

  class LoadCredentialsError < RuntimeError; end

  # Loads the credentials for the AWS SDK V2
  # Attempts to load credentials in the order specified at http://docs.aws.amazon.com/sdkforruby/api/index.html#Configuration
  class Credentials2

    attr_reader :profile_name

    # @param [Hash] options
    # @option options [String] :profile_name (ENV["AWS_DEFAULT_PROFILE"]) The profile name to use
    #    when loading the config from '~/.aws/credentials'.  This can be nil.
    def initialize(options = {})
      @profile_name = options[:profile_name] || ENV["AWS_DEFAULT_PROFILE"]
    end

    # Try to load the credentials from an ordered list of sources and return the first one that
    # can be loaded successfully.
    def get_credentials
      # http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-environment
      credentials_file = ENV.fetch('AWS_SHARED_CREDENTIALS_FILE', ENV['AWS_CONFIG_FILE'])
      shared_creds = ::Aws::SharedCredentials.new(
        :profile_name => profile_name,
        :path => credentials_file
      )
      instance_profile_creds = ::Aws::InstanceProfileCredentials.new(:retries => 1)

      if ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"]
        creds = ::Aws::Credentials.new(
          ENV["AWS_ACCESS_KEY_ID"],
          ENV["AWS_SECRET_ACCESS_KEY"],
          ENV["AWS_SESSION_TOKEN"]
        )
      elsif shared_creds.set?
        creds = shared_creds
      elsif instance_profile_creds.set?
        creds = instance_profile_creds
      else
        raise LoadCredentialsError.new("Could not load credentials from the environment variables, the .aws/credentials file or the metadata service")
      end
      creds
    end
  end

end
end
end

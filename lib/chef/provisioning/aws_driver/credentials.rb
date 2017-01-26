require 'inifile'
require 'csv'
require 'chef/mixin/deep_merge'

class Chef
module Provisioning
module AWSDriver
  # Reads in credential files in Amazon's download format and presents the credentials to you
  class Credentials
    def initialize
      @credentials = {}
      load_default
    end

    include Enumerable
    include Chef::Mixin::DeepMerge

    def default
      if @credentials.size == 0
        raise 'No credentials loaded!  Do you have a ~/.aws/config?'
      end
      @credentials[ENV['AWS_DEFAULT_PROFILE'] || 'default'] || @credentials.first[1]
    end

    def keys
      @credentials.keys
    end

    def [](name)
      @credentials[name]
    end

    def each(&block)
      @credentials.each(&block)
    end

    def load_inis(config_ini_file, credentials_ini_file = nil)
      @credentials = load_config_ini(config_ini_file)
      @credentials = deep_merge!(@credentials,
                                 load_credentials_ini(credentials_ini_file)
                                ) if credentials_ini_file
    end

    def load_config_ini(config_ini_file)
      inifile = IniFile.load(File.expand_path(config_ini_file))
      config = {}
      if inifile
        inifile.each_section do |section|
          if section =~ /^\s*profile\s+(.+)$/ || section =~ /^\s*(default)\s*/
            profile_name = $1.strip
            profile = inifile[section].inject({}) do |result, pair|
              result[pair[0].to_sym] = pair[1]
              result
            end
            profile[:name] = profile_name
            config[profile_name] = profile
          end
        end
      end
      config
    end

    def load_credentials_ini(credentials_ini_file)
      inifile = IniFile.load(File.expand_path(credentials_ini_file))
      config = {}
      if inifile
        inifile.each_section do |section|
          profile = inifile[section].inject({}) do |result, pair|
            result[pair[0].to_sym] = pair[1]
            result
          end
          profile[:name] = section
          config[section] = profile
        end
      end
      config
    end

    def load_csv(credentials_csv_file)
      CSV.new(File.open(credentials_csv_file), :headers => :first_row).each do |row|
        @credentials[row['User Name']] = {
          :name => row['User Name'],
          :user_name => row['User Name'],
          :aws_access_key_id => row['Access Key Id'],
          :aws_secret_access_key => row['Secret Access Key']
        }
      end
    end

    def load_env_variables
      if ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"]
        @credentials["default"] = {
          aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
          aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
        }
      end
    end

    def load_default
      config_file = ENV['AWS_CONFIG_FILE'] || File.expand_path('~/.aws/config')
      credentials_file = ENV['AWS_SHARED_CREDENTIALS_FILE'] || ENV['AWS_CREDENTIAL_FILE'] || File.expand_path('~/.aws/credentials')
      if File.file?(config_file)
        if File.file?(credentials_file)
          load_inis(config_file, credentials_file)
        else
          load_inis(config_file)
        end
      end
      if @credentials.size == 0
        load_env_variables
      end
    end

    def self.method_missing(name, *args, &block)
      singleton.send(name, *args, &block)
    end

    def self.singleton
      @aws_credentials ||= Credentials.new
    end
  end
end
end
end

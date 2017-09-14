require 'spec_helper'

describe Chef::Provisioning::AWSDriver::Credentials do
  context 'loading config INI files' do
    let(:personal_credentials) do
      { region: 'us-west-2',
        aws_access_key_id: 'AKIAPERSONALKEY',
        aws_secret_access_key: 'personalsecretaccesskey',
        name: 'personal'
      }
    end

    let(:work_iam_credentials) do
      { region: 'us-east-1',
        aws_access_key_id: 'AKIAWORKIAMKEY',
        aws_secret_access_key: 'workiamsecretaccesskey',
        name: 'work_iam'
      }
    end

    let(:config_ini_file) do
      @config ||= begin
        ini = Tempfile.new('config_ini')
        ini.write(
          ['[profile personal]',
           'region = us-west-2',
           '[profile work_iam]',
           'region = us-east-1'
          ].join("\n")
        )
        ini.rewind
        ini
      end
      @config
    end

    let(:credential_ini_file) do
      @creds ||= begin
        ini = Tempfile.new('credential_ini')
        ini.write(
          ['[personal]',
           'aws_access_key_id = AKIAPERSONALKEY',
           'aws_secret_access_key = personalsecretaccesskey',
           '[work_iam]',
           'aws_access_key_id = AKIAWORKIAMKEY',
           'aws_secret_access_key = workiamsecretaccesskey'
          ].join("\n")
        )
        ini.rewind
        ini
      end
      @creds
    end

    let(:unified_config_ini_file) do
      @ini ||= begin
        ini = Tempfile.new('unified_config_ini')
        ini.write(
          ['[profile personal]',
           'region = us-west-2',
           'aws_access_key_id = AKIAPERSONALKEY',
           'aws_secret_access_key = personalsecretaccesskey',
           '[profile work_iam]',
           'region = us-east-1',
           'aws_access_key_id = AKIAWORKIAMKEY',
           'aws_secret_access_key = workiamsecretaccesskey'
          ].join("\n")
        )
        ini.rewind
        ini
      end
      @ini
    end

    let(:enterprise_config_ini_file) do
      @ini ||= begin
        ini = Tempfile.new('enterprise_config_ini')
        ini.write(
          ['[profile enterprise]',
           'region = us-west-2',
           'aws_access_key_id = AKIAENTERPRISEKEY',
           'aws_secret_access_key = enterprisesecretaccesskey',
           'aws_session_token = MIIEpAIBAAKCAQEAth95Ci0sdvK222gG2wZEeBXZXeTIynOqJT1fcRnZ/dqVsoUm',
           'proxy_uri = https://user:password@my.proxy:443/path?query',
           '[profile work_iam]',
           'region = us-east-1',
           'aws_access_key_id = AKIAWORKIAMKEY',
           'aws_secret_access_key = workiamsecretaccesskey'
          ].join("\n")
        )
        ini.rewind
        ini
      end
      @ini
    end

    context 'unified config ini file' do
      %w(work_iam personal).each do |profile|
        it "loads the '#{profile}' profile from a unified config file" do
          ENV['AWS_DEFAULT_PROFILE'] = profile
          ENV['AWS_CREDENTIAL_FILE'] = nil
          ENV['AWS_CONFIG_FILE'] = unified_config_ini_file.path
          allow(File)
            .to receive(:file?)
            .with(File.expand_path('~/.aws/credentials'))
            .and_return(false)
          allow(File)
            .to receive(:file?)
            .with(File.expand_path(unified_config_ini_file.path))
            .and_return(true)

          expect(described_class.new.default)
            .to eq(send("#{profile}_credentials"))
        end
      end
    end

    context 'enterprise config ini file' do
      let(:credentials) { described_class.new }
      %w(work_iam enterprise).each do |profile|
        it "loads the '#{profile}' profile from a enterprise config file" do
          ENV['AWS_DEFAULT_PROFILE'] = profile
          ENV['AWS_CREDENTIAL_FILE'] = nil
          ENV['AWS_CONFIG_FILE'] = enterprise_config_ini_file.path
          allow(File)
            .to receive(:file?)
            .with(File.expand_path('~/.aws/credentials'))
            .and_return(false)
          allow(File)
            .to receive(:file?)
            .with(File.expand_path(enterprise_config_ini_file.path))
            .and_return(true)

          if profile.eql?('enterprise')
            expect(credentials[profile][:proxy_uri])
              .to eq('https://user:password@my.proxy:443/path?query')
            expect(credentials[profile][:aws_session_token])
              .to eq('MIIEpAIBAAKCAQEAth95Ci0sdvK222gG2wZEeBXZXeTIynOqJT1fcRnZ/dqVsoUm')
          else
            expect(credentials[profile][:proxy_uri])
              .to eq(nil)
            expect(credentials[profile][:aws_session_token])
              .to eq(nil)
          end
        end
      end
    end

    context 'separate config and credential ini files' do
      %w(work_iam personal).each do |profile|
        it "loads the '#{profile}' profile from a separate config files" do
          ENV['AWS_DEFAULT_PROFILE'] = profile
          ENV['AWS_SHARED_CREDENTIALS_FILE'] = credential_ini_file.path
          ENV['AWS_CONFIG_FILE'] = config_ini_file.path

          expect(described_class.new.default)
            .to eq(send("#{profile}_credentials"))
        end
      end
    end

    context 'backwards compatibility for AWS_CREDENTIAL_FILE env var' do
      %w(work_iam personal).each do |profile|
        it "loads the '#{profile}' profile from a separate config files" do
          ENV['AWS_DEFAULT_PROFILE'] = profile
          ENV['AWS_CREDENTIAL_FILE'] = credential_ini_file.path
          ENV['AWS_CONFIG_FILE'] = config_ini_file.path

          expect(described_class.new.default)
            .to eq(send("#{profile}_credentials"))
        end
      end
    end

  end
end

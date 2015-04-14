require 'spec_helper'

describe Chef::Resource::AwsKeyPair do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do
      before :each do
        driver.ec2.key_pairs['test_key_pair'].delete
      end

      it "aws_key_pair 'test_key_pair' creates a key pair" do
        expect_recipe {
          aws_key_pair 'test_key_pair' do
            private_key_options format: :der, type: :rsa
          end
        }.to create_an_aws_key_pair('test_key_pair').and be_idempotent
      end
    end
  end
end

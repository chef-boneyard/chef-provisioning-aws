require 'spec_helper'

describe Chef::Resource::AwsKeyPair do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do
      before :each do
        driver.ec2.delete_key_pair({key_name: 'test_key_pair'})
      end

      it "aws_key_pair 'test_key_pair' creates a key pair" do
        expect(recipe {
          aws_key_pair 'test_key_pair' do
            private_key_options format: :pem, type: :rsa, regenerate_if_different: true
            allow_overwrite true
          end
        }).to create_an_aws_key_pair('test_key_pair').and be_idempotent
      end
    end
  end
end

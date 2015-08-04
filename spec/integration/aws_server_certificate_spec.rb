require 'spec_helper'

describe Chef::Resource::AwsServerCertificate do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do

    it "creates a cert" do
      expect_recipe {
        aws_server_certificate "test-cert" do
          certificate_body "-----BEGIN CERTIFICATE-----"
          private_key "-----BEGIN RSA PRIVATE KEY-----"
        end
      }.to create_an_aws_server_certificate("test-cert",
                                            certificate_body: "-----BEGIN CERTIFICATE-----"
                                           ).and be_idempotent
    end
  end
end

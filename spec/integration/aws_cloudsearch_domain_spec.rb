require 'spec_helper'

describe Chef::Resource::AwsCloudsearchDomain do
  extend AWSSupport
  when_the_chef_12_server "exists", organization: "foo", server_scope: :context do
    with_aws "when connected to AWS" do
      it "aws_cloudsearch_domain 'test-cloudsearch-domain' creates a cloudsearch domain" do
        expect_recipe {
          aws_cloudsearch_domain "test-cloudsearch-domain" do
            multi_az false
          end
        }.to create_an_aws_cloudsearch_domain("test-cloudsearch-domain", {}).and be_idempotent
      end
    end
  end
end

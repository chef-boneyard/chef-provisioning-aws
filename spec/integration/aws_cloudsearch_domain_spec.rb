require 'spec_helper'

describe Chef::Resource::AwsCloudsearchDomain do
  extend AWSSupport
  when_the_chef_12_server "exists", organization: "foo", server_scope: :context do
    with_aws "when connected to AWS" do

      # Cloudsearch can take forevvvver to delete so we need to randomize our names
      time = DateTime.now.strftime('%Q')

      it "aws_cloudsearch_domain 'test-#{time}' creates a cloudsearch domain" do
        expect_recipe {
          aws_cloudsearch_domain "test-#{time}" do
            multi_az false
          end
        }.to create_an_aws_cloudsearch_domain("test-#{time}", {}).and be_idempotent
      end

      it "returns nil when aws_object is called for something that does not exist" do
        r = nil
        converge {
          r = aws_cloudsearch_domain "wont-exist" do
            action :nothing
          end
        }
        expect(r.aws_object).to eq(nil)
      end

    end
  end
end

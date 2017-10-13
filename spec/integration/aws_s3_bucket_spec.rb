require 'spec_helper'
require 'securerandom'

def mk_bucket_name
  bucket_postfix = SecureRandom.hex(8)
  "chef.provisioning.test.#{bucket_postfix}"
end

describe Chef::Resource::AwsS3Bucket do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: "foo", server_scope: :context do
    with_aws "when connected to AWS" do
      bucket_name = mk_bucket_name

      it "aws_s3_bucket '#{bucket_name}' creates a bucket" do
        expect_recipe {
          aws_s3_bucket bucket_name
        }.to create_an_aws_s3_bucket(bucket_name).and be_idempotent
      end

      it "creates aws_s3_bucket tags" do
        expect_recipe {
          aws_s3_bucket bucket_name do
            aws_tags key1: "value"
          end
        }.to create_an_aws_s3_bucket(bucket_name)
        .and have_aws_s3_bucket_tags(bucket_name,
          {
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        aws_s3_bucket bucket_name do
          aws_tags key1: "value"
        end

        it "updates aws_s3_bucket tags" do
          expect_recipe {
            aws_s3_bucket bucket_name do
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_s3_bucket_tags(bucket_name,
            {
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_s3_bucket tags" do

          expect_recipe {
            aws_s3_bucket bucket_name do
              aws_tags({})
            end
          }.to have_aws_s3_bucket_tags(bucket_name, {}).and be_idempotent
        end
      end

    end

    with_aws "when a bucket with content exists" do
      bucket_name = mk_bucket_name
      with_converge {
        aws_s3_bucket bucket_name

        ruby_block "upload s3 object" do
          block do
            ::Aws::S3::Resource.new(driver.s3_client).buckets.find { |b| b.name == bucket_name }.object("test-object").put( { body: "test-content" } )
          end
        end
      }

      it "aws_s3_bucket '#{bucket_name}' with recursive_delete set to true, deletes the bucket" do
        r = recipe {
          aws_s3_bucket bucket_name do
            recursive_delete true
            action :delete
          end
        }
        expect(r).to destroy_an_aws_s3_bucket(bucket_name)
      end
    end
  end
end

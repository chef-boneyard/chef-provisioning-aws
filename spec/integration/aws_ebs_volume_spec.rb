require 'spec_helper'

describe Chef::Resource::AwsEbsVolume do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do

      it "aws_ebs_volume 'test_volume' creates an ebs volume" do
        expect_recipe {
          aws_ebs_volume "test_volume" do
            availability_zone 'a'
            size 8
          end
        }.to create_an_aws_ebs_volume('test_volume')
         .and be_idempotent
      end

      it "aws_ebs_volume 'test_volume_az' creates an ebs volume with proper AZ" do
        expect_recipe {
          aws_ebs_volume "test_volume_az" do
            availability_zone 'us-abcd-1a'
            size 8
          end
        }.to create_an_aws_ebs_volume('test_volume_az')
         .and be_idempotent
      end

      it "aws_ebs_volume fails with an invalid AZ pattern", :skip => true do
        expect_recipe {
          aws_ebs_volume "test_volume_az0" do
            availability_zone 'usa-abcd-1'
            size 8
          end
        }.to raise_error(Chef::Exceptions::ValidationFailed, /availability_zone/)
      end
    end
  end
end

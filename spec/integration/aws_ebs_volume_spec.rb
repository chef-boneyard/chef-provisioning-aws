require 'spec_helper'

describe Chef::Resource::AwsEbsVolume do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do

      it "aws_ebs_volume 'test_volume' creates an ebs volume" do
        expect_recipe {
          aws_ebs_volume "test_volume"
        }.to create_an_aws_ebs_volume('test_volume',
          :size => 8
        ).and be_idempotent
      end

      describe 'action :delete' do
        with_converge {
          aws_ebs_volume "test_volume" do
            availability_zone 'a'
            size 8
          end
        }
        it "deletes the ebs volume" do
          expect_recipe {
            aws_ebs_volume "test_volume" do
              action :destroy
            end
          }.to destroy_an_aws_ebs_volume('test_volume')
           .and be_idempotent
        end
      end

      it "aws_ebs_volume 'test_volume_az' creates an ebs volume when provided proper full AZ" do
        expect_recipe {
          aws_ebs_volume "test_volume_az" do
            availability_zone "#{driver.aws_config.region}a"
          end
        }.to create_an_aws_ebs_volume('test_volume_az')
         .and be_idempotent
      end

    end
  end
end

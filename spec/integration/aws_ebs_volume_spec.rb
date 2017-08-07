require 'spec_helper'

describe Chef::Resource::AwsEbsVolume do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do

      it "aws_ebs_volume 'test_volume' creates an ebs volume" do
        expect_recipe {
          aws_ebs_volume "test_volume"
        }.to create_an_aws_ebs_volume('test_volume',
          size: 8
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
          # TODO all the `with_*` and `expect_*` methods from Cheffish
          # automatically converge the block - we don't want to do that,
          # we want to let the `destroy_an*` matcher do that
          r = recipe {
            aws_ebs_volume "test_volume" do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_ebs_volume('test_volume'
          ).and be_idempotent
        end
      end

      it "aws_ebs_volume 'test_volume_az' creates an ebs volume when provided proper full AZ" do
        expect_recipe {
          aws_ebs_volume "test_volume_az" do
            availability_zone "#{driver.region}a"
          end
        }.to create_an_aws_ebs_volume('test_volume_az')
         .and be_idempotent
      end

      # These tests are testing the tagging functionality - they use some example resources rather
      # because these are integration tests so we cannot make a mock resource.
      it "aws_ebs_volume 'test_volume' created with default Name tag" do
        expect_recipe {
          aws_ebs_volume "test_volume"
        }.to create_an_aws_ebs_volume('test_volume'
        ).and have_aws_ebs_volume_tags('test_volume',
                       { 'Name' => 'test_volume' }
        ).and be_idempotent
      end

      it "allows users to specify a unique Name tag" do
        expect_recipe {
          aws_ebs_volume "test_volume_2" do
            aws_tags :Name => 'test_volume_new'
          end
        }.to create_an_aws_ebs_volume('test_volume_2'
        ).and have_aws_ebs_volume_tags('test_volume_2',
                                      { 'Name' => 'test_volume_new' }
        ).and be_idempotent
      end

      it "allows tags to be specified as strings or symbols" do
        expect_recipe {
          aws_ebs_volume "test_volume" do
            aws_tags({
              :key1 => :symbol,
              'key2' => :symbol,
              :key3 => 'string',
              'key4' => 'string'
            })
          end
        }.to create_an_aws_ebs_volume('test_volume'
        ).and have_aws_ebs_volume_tags('test_volume',
                       {
                         'key1' => 'symbol',
                         'key2' => 'symbol',
                         'key3' => 'string',
                         'key4' => 'string'
                       }
        ).and be_idempotent
      end

      context "when there are existing tags" do
        before(:each) do
          converge {
            aws_ebs_volume "test_volume_a" do
              aws_tags :byebye => 'true'
            end
          }
        end

        after(:each) do
          converge {
            aws_ebs_volume "test_volume_a" do
              action :purge
            end
          }
        end

        it "updates the tags" do
          expect_recipe {
            aws_ebs_volume "test_volume_a" do
              aws_tags 'Name' => 'test_volume_b', :project => 'X'
            end
          }.to have_aws_ebs_volume_tags('test_volume_a',
                                        {
                                          'Name' => 'test_volume_b',
                                          'project' => 'X'
                                        }
          ).and be_idempotent
        end

        it "deletes the tags" do
          expect_recipe {
            aws_ebs_volume "test_volume_a" do
              aws_tags({})
            end
          }.to have_aws_ebs_volume_tags('test_volume_a',
                                        {
                                          'Name' => 'test_volume_a',
                                        }
          ).and be_idempotent
        end

        it "aws_ebs_volume 'test_volume' tags are not changed when not updated" do
          expect_recipe {
            #aws_ebs_volume "test_volume_a"
          }.to have_aws_ebs_volume_tags('test_volume_a',
                                        {
                                          'Name' => 'test_volume_a',
                                          'byebye' => 'true'
                                        }
          )
        end
      end

    end
  end
end

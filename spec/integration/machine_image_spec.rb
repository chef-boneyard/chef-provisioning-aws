require 'spec_helper'

describe Chef::Resource::MachineImage do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC and a public subnet" do
      before :all do
        chef_config[:log_level] = :warn
      end

      purge_all
      setup_public_vpc

      it "machine_image can create an image in the VPC", :super_slow do
        expect_recipe {
          machine_image 'test_machine_image' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair'
            }
          end
        }.to create_an_aws_image('test_machine_image',
          name: 'test_machine_image'
        ).and be_idempotent
      end
    end

    with_aws "Without a VPC" do
      before :all do
        chef_config[:log_level] = :warn
      end

      aws_key_pair 'test_key_pair' do
        allow_overwrite true
      end

      it "machine_image with no options can create an image in the VPC", :super_slow do
        expect_recipe {
          machine_image 'test_machine_image' do
            machine_options bootstrap_options: { key_name: 'test_key_pair' }
          end
        }.to create_an_aws_image('test_machine_image',
          name: 'test_machine_image'
        ).and be_idempotent
      end

      it "creates aws_image tags", :super_slow do
        expect_recipe {
          machine_image 'test_machine_image' do
            machine_options bootstrap_options: { key_name: 'test_key_pair' }
            aws_tags key1: "value"
          end
        }.to create_an_aws_image('test_machine_image')
        .and have_aws_image_tags('test_machine_image',
          {
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        machine_image 'test_machine_image' do
          machine_options bootstrap_options: { key_name: 'test_key_pair' }
          aws_tags key1: "value"
        end

        it "updates aws_image tags", :super_slow do
          expect_recipe {
            machine_image 'test_machine_image' do
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_image_tags('test_machine_image',
            {
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_image tags", :super_slow do
          expect_recipe {
            machine_image 'test_machine_image' do
              aws_tags {}
            end
          }.to have_aws_image_tags('test_machine_image',
            {}
          ).and be_idempotent
        end
      end

    end
  end
end

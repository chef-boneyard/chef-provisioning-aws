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

      it "machine_image with no options can create an image in the VPC", :super_slow do
        expect_recipe {
          aws_key_pair 'test_key_pair' do
            allow_overwrite true
          end
          machine_image 'test_machine_image' do
            machine_options bootstrap_options: { key_name: 'test_key_pair' }
          end
        }.to create_an_aws_image('test_machine_image',
          name: 'test_machine_image'
        ).and create_an_aws_key_pair('test_key_pair'
        ).and be_idempotent
      end
    end
  end
end

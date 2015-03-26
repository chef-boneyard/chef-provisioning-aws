require 'spec_helper'

describe Chef::Resource::Machine do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC and a public subnet" do
      purge_all
      setup_public_vpc

      it "machine with few options creates a machine in the VPC", :super_slow do
        expect_recipe {
          machine 'test_machine' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair'
            }
          end
        }.to create_an_aws_instance('test_machine'
        ).and be_idempotent
      end
    end

    with_aws "Without a VPC" do
      it "machine with no options can create an image in the VPC", :super_slow do
        expect_recipe {
          machine 'test_machine' do
            machine_options bootstrap_options: { key_name: 'test_key_pair' }
          end
        }.to create_an_aws_instance('test_machine'
        ).and be_idempotent
      end
    end
  end
end

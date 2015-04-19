require 'spec_helper'

describe Chef::Resource::Machine do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC and a public subnet" do

      before :all do
        chef_config[:log_level] = :warn
      end

      purge_all
      setup_public_vpc

      it "machine with few options allocates a machine", :super_slow do
        expect_recipe {
          machine 'test_machine' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair'
            }
            action :allocate
          end
        }.to create_an_aws_instance('test_machine'
        ).and be_idempotent
      end

      it "machine with few options converges a machine", :super_slow do
        expect_recipe {
          machine 'test_machine' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair'
            }
            action :allocate
          end
        }.to create_an_aws_instance('test_machine'
        ).and be_idempotent
      end

      it "machine with source_dest_check false creates a machine with no source dest check", :super_slow do
        expect_recipe {
          machine 'test_machine' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair'
            }, source_dest_check: false
            action :allocate
          end
        }.to create_an_aws_instance('test_machine',
          source_dest_check: false
        ).and be_idempotent
      end
    end

    with_aws "Without a VPC" do

      before :all do
        chef_config[:log_level] = :warn
      end

      #purge_all
      it "machine with no options creates an machine", :super_slow do
        expect_recipe {
          aws_key_pair 'test_key_pair' do
            allow_overwrite true
          end
          machine 'test_machine' do
            machine_options bootstrap_options: { key_name: 'test_key_pair' }
            action :allocate
          end
        }.to create_an_aws_instance('test_machine'
        ).and create_an_aws_key_pair('test_key_pair'
        ).and be_idempotent
      end
    end
  end
end

require 'spec_helper'

describe Chef::Resource::MachineBatch do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC and a public subnet" do

      before :all do
        chef_config[:log_level] = :warn
      end

      purge_all
      setup_public_vpc
      it "machine_batch creates multiple machines", :super_slow do
        expect_recipe {
          machine_batch 'test_machines' do
            (1..3).each do |i|
              machine "test_machine#{i}" do
                machine_options bootstrap_options: {
                  subnet_id: 'test_public_subnet',
                  key_name: 'test_key_pair'
                }, source_dest_check: false
                action :allocate
              end
            end
            action :allocate
          end
        }.to create_an_aws_instance('test_machine1',
          source_dest_check: false
        ).and create_an_aws_instance('test_machine2',
          source_dest_check: false
        ).and create_an_aws_instance('test_machine3',
          source_dest_check: false
        ).and be_idempotent
      end
    end

  end
end

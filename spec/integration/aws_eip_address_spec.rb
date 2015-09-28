require 'spec_helper'

describe Chef::Resource::AwsEipAddress do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do

      it "aws_eip_address 'test_eip' creates an elastic ip" do
        expect_recipe {
          aws_eip_address "test_eip"
        }.to create_an_aws_eip_address('test_eip',
        ).and be_idempotent
      end

      describe 'action :delete' do
        with_converge {
          aws_eip_address "test_eip"
        }
        it "deletes the elastic ip" do
          # TODO all the `with_*` and `expect_*` methods from Cheffish
          # automatically converge the block - we don't want to do that,
          # we want to let the `destroy_an*` matcher do that
          r = recipe {
            aws_eip_address "test_eip" do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_eip_address('test_eip'
          ).and be_idempotent
        end
      end

      context "with existing machines", :super_slow do
        purge_all
        setup_public_vpc

        machine 'test_machine' do
          machine_options bootstrap_options: {
            subnet_id: 'test_public_subnet',
            key_name: 'test_key_pair'
          }
          action :ready # The box has to be online for AWS to accept it as routable
        end

        it "associates an EIP with a machine" do
          test_machine_aws_obj = nil
          expect_recipe {
            ruby_block 'look up test machine' do
              block do
                test_machine_aws_obj = Chef::Resource::AwsInstance.get_aws_object(
                  'test_machine',
                  run_context: run_context,
                  driver: run_context.chef_provisioning.current_driver,
                  managed_entry_store: Chef::Provisioning.chef_managed_entry_store(run_context.cheffish.current_chef_server)
                )
              end
            end
          }

          expect_recipe {
            aws_eip_address "test_eip" do
              associate_to_vpc true
              machine "test_machine"
            end
          }.to create_an_aws_eip_address('test_eip',
            instance_id: test_machine_aws_obj.id
          ).and be_idempotent
        end

      end
    end
  end
end

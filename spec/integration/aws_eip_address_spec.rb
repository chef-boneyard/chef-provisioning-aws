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

      it "raises an error trying to reference an eip that does not exist" do
        r = recipe {
          aws_eip_address "0.0.0.0"
        }
        expect {r.converge}.to raise_error(/Chef::Resource::AwsEipAddress\[0.0.0.0\] does not exist!/)
      end

      context "with an existing aws_eip_address" do
        aws_eip_address "test_eip"

        it "can reference the ip address by id in the name field" do
          expect_recipe {
            aws_eip_address test_eip.aws_object.public_ip
          }.to match_an_aws_eip_address(test_eip.aws_object.public_ip,
            public_ip: test_eip.aws_object.public_ip
          ).and be_idempotent
        end

        it "can reference the ip address in the public_ip field" do
          expect_recipe {
            aws_eip_address "random_identifier" do
              public_ip test_eip.aws_object.public_ip
            end
          }.to match_an_aws_eip_address("random_identifier",
            public_ip: test_eip.aws_object.public_ip
          ).and be_idempotent
        end
      end

      describe 'action :delete' do
        aws_eip_address "test_eip"

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
          expect_recipe {
            aws_eip_address "test_eip" do
              associate_to_vpc true
              machine "test_machine"
            end
          }.to create_an_aws_eip_address('test_eip',
            instance_id: test_machine.aws_object.id
          ).and be_idempotent
        end

      end
    end
  end
end

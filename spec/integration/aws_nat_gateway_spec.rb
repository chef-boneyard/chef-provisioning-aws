require 'spec_helper'
require 'chef/resource/aws_nat_gateway'

describe Chef::Resource::AwsNatGateway do
  extend AWSSupport

  when_the_chef_12_server 'exists', organization: 'foo', server_scope: :context do
    with_aws 'with a VPC' do
      purge_all
      setup_public_vpc

      aws_network_interface 'test_network_interface' do
       subnet 'test_public_subnet'
      end

      describe 'action :create' do #, :super_slow do
        it 'creates an aws_nat_gateway in the specified subnet creating an eip dynamically' do
          expect_recipe {
            aws_nat_gateway 'test_nat_gateway' do
              subnet 'test_public_subnet'
            end
          }.to create_an_aws_nat_gateway('test_nat_gateway',
            subnet_id: test_public_subnet.aws_object.id
          ).and be_idempotent
        end

        context 'when an eip address is given' do
          aws_eip_address 'test_eip'

          it 'creates an aws_nat_gateway in the specified subnet with that eip' do
            expect_recipe {
              aws_nat_gateway 'test_nat_gateway' do
                subnet 'test_public_subnet'
                eip_address 'test_eip'
              end
            }.to create_an_aws_nat_gateway('test_nat_gateway',
              subnet_id: test_public_subnet.aws_object.subnet_id,
              nat_gateway_addresses: [ allocation_id: test_eip.aws_object.allocation_id ]
            ).and be_idempotent
          end
        end
      end

      describe 'action :delete' do #, :super_slow do
        context 'when there is a nat_gateway with elastic ip dynamically created' do
          aws_nat_gateway 'test_nat_gateway' do
            subnet 'test_public_subnet'
          end

          it 'deletes the nat gateway and the elastic ip as well' do
            r = recipe {
              aws_nat_gateway 'test_nat_gateway' do
                action :destroy
              end
            }
            expect(r).to destroy_an_aws_nat_gateway('test_nat_gateway'
            ).and destroy_an_aws_eip_address('test_nat_gateway-eip'
            ).and be_idempotent
          end
        end
      end

      describe 'action :purge' do #, :super_slow do
        context 'when there is a nat_gateway and an elastic ip manually created' do
          aws_eip_address 'test_eip'

          aws_nat_gateway 'test_nat_gateway' do
            subnet 'test_public_subnet'
            eip_address 'test_eip'
          end

          it 'deletes the nat gateway and the given elastic ip' do
            r = recipe {
              aws_nat_gateway 'test_nat_gateway' do
                action :purge
              end
            }

            expect(r).to destroy_an_aws_nat_gateway('test_nat_gateway'
            ).and destroy_an_aws_eip_address('test_eip'
            ).and be_idempotent
          end
        end
      end
    end
  end
end

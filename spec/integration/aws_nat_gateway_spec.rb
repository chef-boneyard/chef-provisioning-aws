require 'spec_helper'
require 'chef/resource/aws_nat_gateway'

describe Chef::Resource::AwsNatGateway do
  extend AWSSupport

  when_the_chef_12_server 'exists', organization: 'foo', server_scope: :context do
    with_aws 'with a VPC' do
      purge_all
      setup_public_vpc

      aws_eip_address "test_eip"

      describe 'action :create' do #, :super_slow do
        it 'creates an aws_nat_gateway in the specified subnet' do
          expect_recipe {
            sub_id = test_public_subnet.aws_object.id
            aws_nat_gateway 'test_nat_gateway' do
              subnet sub_id
              eip_address 'test_eip'
            end
          }.to create_an_aws_nat_gateway('test_nat_gateway',
            subnet_id: test_public_subnet.aws_object.id
          ).and be_idempotent
        end
      end

      describe 'action :delete' do
        context 'when there is a nat_gateway' do
          aws_nat_gateway 'test_nat_gateway' do
            subnet 'test_public_subnet'
            eip_address 'test_eip'
          end

          it 'deletes the nat gateway and does not delete the eip address' do
            r = recipe {
              aws_nat_gateway 'test_nat_gateway' do
                action :destroy
              end
            }
            expect(r).to destroy_an_aws_nat_gateway('test_nat_gateway'
            ).and match_an_aws_eip_address('test_eip'
            ).and be_idempotent
          end
        end
      end
    end
  end
end

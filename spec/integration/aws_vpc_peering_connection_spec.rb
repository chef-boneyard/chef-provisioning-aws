require 'spec_helper'

describe Chef::Resource::AwsVpcPeeringConnection do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with 2 VPCs" do

      aws_vpc "test_vpc" do
        cidr_block '10.0.0.0/24'
        internet_gateway false
      end

      aws_vpc "test_vpc_2" do
        cidr_block '11.0.0.0/24'
        internet_gateway false
      end

      it "aws_peering_connection 'test_vpc' with no attributes fails to create a VPC peering connection (must specify vpc and peer_vpc)" do
        expect_converge {
          aws_vpc_peering_connection 'test_peering_connection' do
          end
        }.to raise_error(RuntimeError, /VCP peering connection create action for 'test_peering_connection' requires the 'vpc' attribute./)

        expect_converge {
          aws_vpc_peering_connection 'test_peering_connection' do
            vpc 'test_vpc'
          end
        }.to raise_error(RuntimeError, /VCP peering connection create action for 'test_peering_connection' requires the 'peer_vpc' attribute./)
      end

      it "aws_peering_connection 'test_peering_connection' with minimal parameters creates a active connection" do
        expect_recipe {
          aws_vpc_peering_connection 'test_peering_connection' do
            vpc 'test_vpc'
            peer_vpc 'test_vpc_2'
          end
        }.to create_an_aws_vpc_peering_connection('test_peering_connection',
          :'requester_vpc_info.vpc_id' => test_vpc.aws_object.id,
          :'accepter_vpc_info.vpc_id' => test_vpc_2.aws_object.id,
          :'status.code' => 'active'
        ).and be_idempotent
      end

      it "aws_peering_connection 'test_peering_connection' with peer_owner_id set to be the actual account id, creates an active peering" do
        expect_recipe {
          aws_vpc_peering_connection 'test_peering_connection' do
            vpc 'test_vpc'
            peer_vpc 'test_vpc_2'
            peer_owner_id driver.account_id
          end
        }.to create_an_aws_vpc_peering_connection('test_peering_connection',
            :'requester_vpc_info.vpc_id' => test_vpc.aws_object.id,
            :'accepter_vpc_info.vpc_id' => test_vpc_2.aws_object.id,
            :'status.code' => 'active'
         ).and be_idempotent
      end

      it "aws_peering_connection 'test_peering_connection' with a false peer_owner_id, creates a failed peering connection" do
        expect_recipe {
          aws_vpc_peering_connection 'test_peering_connection' do
            vpc 'test_vpc'
            peer_vpc 'test_vpc_2'
            peer_owner_id '000000000000'
          end
        }.to create_an_aws_vpc_peering_connection('test_peering_connection',
            :'requester_vpc_info.vpc_id' => test_vpc.aws_object.id,
            :'accepter_vpc_info.vpc_id' => test_vpc_2.aws_object.id,
            :'status.code' => 'failed'
        ).and be_idempotent
      end

      it "aws_peering_connection 'test_peering_connection' with accept action, accepts a pending peering connection" do
        pcx = nil
        ec2_resource = driver.ec2_resource
        expect_recipe {
          ruby_block "fetch VPC objects" do
            block do
              test_vpc = Chef::Resource::AwsVpc.get_aws_object("test_vpc", run_context: run_context)
              test_vpc_2 = Chef::Resource::AwsVpc.get_aws_object("test_vpc_2", run_context: run_context)
              pcx = ec2_resource.vpc(test_vpc.id).request_vpc_peering_connection({ :peer_vpc_id => test_vpc_2.id })
            end
          end
        }.to match_an_aws_vpc_peering_connection(pcx.id,
           :'status.code' => 'pending-acceptance'
        )

        expect_recipe {
          aws_vpc_peering_connection pcx.id do
            action :accept
          end
        }.to match_an_aws_vpc_peering_connection(pcx.id,
          :'status.code' => 'active'
        )
      end
    end
  end
end


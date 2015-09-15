require 'spec_helper'

describe Chef::Resource::AwsRouteTable do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC with an internet gateway" do
      aws_vpc "test_vpc" do
        cidr_block '10.0.0.0/24'
        internet_gateway true
      end

      it "aws_route_table 'test_route_table' with no parameters except VPC creates a route table" do
        expect_recipe {
          aws_route_table 'test_route_table' do
            vpc 'test_vpc'
          end
        }.to create_an_aws_route_table('test_route_table',
          routes: [
            { destination_cidr_block: '10.0.0.0/24', 'target.id' => 'local', state: :active }
          ]
        ).and be_idempotent
      end

      it "aws_route_table 'test_route_table' with routes creates a route table" do
        expect_recipe {
          aws_route_table 'test_route_table' do
            vpc 'test_vpc'
            routes '0.0.0.0/0' => :internet_gateway
          end
        }.to create_an_aws_route_table('test_route_table',
          routes: [
            { destination_cidr_block: '10.0.0.0/24', 'target.id' => 'local', state: :active },
            { destination_cidr_block: '0.0.0.0/0', 'target.id' => test_vpc.aws_object.internet_gateway.id, state: :active }
          ]
        ).and be_idempotent
      end

      it "ignores routes whose target matches ignore_route_targets" do
        eni = nil
        expect_recipe {
            aws_subnet 'test_subnet' do
              vpc 'test_vpc'
            end

            eni = aws_network_interface 'test_network_interface' do
              subnet 'test_subnet'
            end

            aws_route_table 'test_route_table' do
              vpc 'test_vpc'
              routes(
                '0.0.0.0/0' => :internet_gateway,
                '172.31.0.0/16' => eni
              )
            end

            aws_route_table 'test_route_table' do
              vpc 'test_vpc'
              routes '0.0.0.0/0' => :internet_gateway
              ignore_route_targets ['^eni-']
            end
          }.to create_an_aws_route_table('test_route_table',
            routes: [
              { destination_cidr_block: '10.0.0.0/24', 'target.id' => 'local', state: :active },
              { destination_cidr_block: '172.31.0.0/16', 'target.id' => eni.aws_object.id, state: :blackhole },
              { destination_cidr_block: '0.0.0.0/0', 'target.id' => test_vpc.aws_object.internet_gateway.id, state: :active },
            ]
          ).and be_idempotent
      end

      it "creates aws_route_table tags" do
        expect_recipe {
          aws_route_table 'test_route_table' do
            vpc 'test_vpc'
            aws_tags key1: "value"
          end
        }.to create_an_aws_route_table('test_route_table')
        .and have_aws_route_table_tags('test_route_table',
          {
            'Name' => 'test_route_table',
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        aws_route_table 'test_route_table' do
          vpc 'test_vpc'
          aws_tags key1: "value"
        end

        it "updates aws_route_table tags" do
          expect_recipe {
            aws_route_table 'test_route_table' do
              vpc 'test_vpc'
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_route_table_tags('test_route_table',
            {
              'Name' => 'test_route_table',
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_route_table tags except Name" do
          expect_recipe {
            aws_route_table 'test_route_table' do
              vpc 'test_vpc'
              aws_tags {}
            end
          }.to have_aws_route_table_tags('test_route_table',
            {
              'Name' => 'test_route_table'
            }
          ).and be_idempotent
        end
      end

    end
  end
end

require 'spec_helper'

describe Chef::Resource::AwsRouteTable do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC with an internet gateway" do
      purge_all
      setup_public_vpc

      aws_network_interface 'test_network_interface' do
        subnet 'test_public_subnet'
      end

      it "aws_route_table 'test_route_table' with no parameters except VPC creates a route table" do
        expect_recipe {
          aws_route_table 'test_route_table' do
            vpc 'test_vpc'
          end
        }.to create_an_aws_route_table('test_route_table',
          routes: [
            { destination_cidr_block: '10.0.0.0/16', gateway_id: 'local', state: "active" }
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
          routes: Set[
            { destination_cidr_block: '10.0.0.0/16', gateway_id: 'local', state: "active" },
            { destination_cidr_block: '0.0.0.0/0', gateway_id: test_vpc.aws_object.internet_gateways.first.id, state: "active" }
          ]
        ).and be_idempotent
      end

      it "ignores routes whose target matches ignore_route_targets" do
        expect_recipe {
            aws_route_table 'test_route_table' do
              vpc 'test_vpc'
              routes(
                '0.0.0.0/0' => :internet_gateway,
                '172.31.0.0/16' => test_network_interface
              )
            end

            aws_route_table 'test_route_table' do
              vpc 'test_vpc'
              routes '0.0.0.0/0' => :internet_gateway
              ignore_route_targets ['^eni-']
            end
          }.to create_an_aws_route_table('test_route_table',
            routes: Set[
              { destination_cidr_block: '10.0.0.0/16', gateway_id: 'local', state: "active" },
              { destination_cidr_block: '172.31.0.0/16', network_interface_id: test_network_interface.aws_object.id, state: "blackhole" },
              { destination_cidr_block: '0.0.0.0/0', gateway_id: test_vpc.aws_object.internet_gateways.first.id, state: "active" },
            ]
          ).and be_idempotent
      end

      context "with an existing routing table" do
        aws_route_table 'test_route_table' do
          vpc 'test_vpc'
          routes '0.0.0.0/0' => :internet_gateway,
                 '1.0.0.0/8' => :internet_gateway
        end

        it "updates an existing routing table" do
          expect_recipe {
            aws_route_table 'test_route_table' do
              vpc 'test_vpc'
              routes '0.0.0.0/0' => :internet_gateway,
                    '2.0.0.0/8' => :internet_gateway
            end
          }.to update_an_aws_route_table('test_route_table',
            routes: Set[
              { destination_cidr_block: '2.0.0.0/8', gateway_id: test_vpc.aws_object.internet_gateways.first.id, state: "active" },
              { destination_cidr_block: '10.0.0.0/16', gateway_id: 'local', state: "active" },
              { destination_cidr_block: '0.0.0.0/0', gateway_id: test_vpc.aws_object.internet_gateways.first.id, state: "active" },
            ]
          ).and be_idempotent
        end
      end

      context "with nat gateway" do
        aws_eip_address 'test_eip'
        aws_nat_gateway 'test_nat_gateway' do
          subnet 'test_public_subnet'
          eip_address 'test_eip'
        end

        it "can route to a nat gateway" do
          expect_recipe {
            aws_route_table 'test_route_table' do
              vpc 'test_vpc'
              routes '0.0.0.0/0' => test_nat_gateway
            end
          }.to create_an_aws_route_table('test_route_table',
            routes: Set[
                { destination_cidr_block: '10.0.0.0/16', gateway_id: 'local', state: 'active' },
                { destination_cidr_block: '0.0.0.0/0', nat_gateway_id: test_nat_gateway.aws_object.nat_gateway_id, state: 'active' },
              ]
          ).and be_idempotent
        end
      end

      context "with machines", :super_slow do
        machine 'test_machine' do
          machine_options bootstrap_options: {
            subnet_id: 'test_public_subnet',
            key_name: 'test_key_pair'
          }
          action :ready # The box has to be online for AWS to accept it as routable
        end

        it "can route to a machine", :super_slow do
          expect_recipe {
            aws_route_table 'test_route_table' do
              vpc 'test_vpc'
              routes '0.0.0.0/0'   => :internet_gateway,
                     '11.0.0.0/8' => 'test_machine'
            end

          }.to create_an_aws_route_table('test_route_table',
            routes: Set[
                { destination_cidr_block: '10.0.0.0/16', gateway_id: 'local', state: "active" },
                { destination_cidr_block: '11.0.0.0/8', instance_id: test_machine.aws_object.id, state: "active" },
                { destination_cidr_block: '0.0.0.0/0', gateway_id: test_vpc.aws_object.internet_gateways.first.id, state: "active" },
              ]
          ).and be_idempotent
        end
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
              aws_tags({})
            end
          }.to have_aws_route_table_tags('test_route_table',
            {
              'Name' => 'test_route_table'
            }
          ).and be_idempotent
        end
      end

    end

    with_aws "with two VPC's with an internet gateway" do
      aws_vpc "test_vpc_1" do
        cidr_block '10.0.0.0/24'
        internet_gateway true
      end

      aws_vpc "test_vpc_2" do
        cidr_block '11.0.0.0/24'
        internet_gateway false
      end

      it "aws_route_table 'test_route_table' with routes to differents targets creates a route table" do
        pcx = nil
        expect_recipe {
          pcx = aws_vpc_peering_connection 'test_peering_connection' do
            vpc 'test_vpc_1'
            peer_vpc 'test_vpc_2'
          end

          aws_route_table 'test_route_table' do
            vpc 'test_vpc_1'
            routes(
                '100.100.0.0/16' => pcx,
                '0.0.0.0/0' => :internet_gateway
            )
          end
        }.to create_an_aws_route_table('test_route_table',
          routes: Set[
            { destination_cidr_block: '10.0.0.0/24', gateway_id: 'local', state: "active" },
            { destination_cidr_block: '100.100.0.0/16', vpc_peering_connection_id: pcx.aws_object.id, state: "active" },
            { destination_cidr_block: '0.0.0.0/0', gateway_id: test_vpc_1.aws_object.internet_gateways.first.id, state: "active" }
          ]
        ).and be_idempotent
      end
    end
  end
end

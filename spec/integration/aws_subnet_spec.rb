require 'spec_helper'

describe Chef::Resource::AwsSubnet do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC with an internet gateway, route table and network acl" do
      aws_vpc "test_vpc" do
        cidr_block '10.0.0.0/24'
        internet_gateway true
      end

      aws_route_table 'test_route_table' do
        vpc 'test_vpc'
      end

      aws_network_acl 'test_network_acl' do
        vpc 'test_vpc'
      end

      it "aws_subnet 'test_subnet' with no parameters except VPC creates a subnet" do
        expect_recipe {
          aws_subnet 'test_subnet' do
            vpc 'test_vpc'
          end
        }.to create_an_aws_subnet('test_subnet',
          vpc_id: test_vpc.aws_object.id,
          cidr_block: test_vpc.aws_object.cidr_block
        ).and be_idempotent
      end

      it "aws_subnet 'test_subnet' with all parameters creates a subnet" do
        az = driver.ec2_client.describe_availability_zones.availability_zones.first.zone_name
        na = test_network_acl.aws_object.id
        rt = test_route_table.aws_object.id
        expect_recipe {
          aws_subnet 'test_subnet' do
            vpc 'test_vpc'
            cidr_block '10.0.0.0/24'
            availability_zone az
            map_public_ip_on_launch true
            route_table 'test_route_table'
            network_acl 'test_network_acl'
          end
        }.to create_an_aws_subnet('test_subnet',
          vpc_id: test_vpc.aws_object.id,
          cidr_block: '10.0.0.0/24',
          availability_zone: az
        ).and match_an_aws_subnet('test_subnet',
          subnet_id: driver.ec2_client.describe_route_tables(filters: [{name: "route-table-id", values: [rt]}]).route_tables[0].associations[0].subnet_id
        ).and match_an_aws_subnet('test_subnet',
          subnet_id: driver.ec2_client.describe_network_acls(filters: [{name: "network-acl-id", values: [na]}]).network_acls[0].associations[0].subnet_id
        ).and be_idempotent
      end

      it "creates aws_subnet tags" do
        expect_recipe {
          aws_subnet 'test_subnet' do
            vpc 'test_vpc'
            aws_tags key1: "value"
          end
        }.to create_an_aws_subnet('test_subnet')
        .and have_aws_subnet_tags('test_subnet',
          {
            'Name' => 'test_subnet',
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        aws_subnet 'test_subnet' do
          vpc 'test_vpc'
          aws_tags key1: "value"
        end

        it "updates aws_subnet tags" do
          expect_recipe {
            aws_subnet 'test_subnet' do
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_subnet_tags('test_subnet',
            {
              'Name' => 'test_subnet',
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_subnet tags except Name" do
          expect_recipe {
            aws_subnet 'test_subnet' do
              aws_tags({})
            end
          }.to have_aws_subnet_tags('test_subnet',
            {
              'Name' => 'test_subnet'
            }
          ).and be_idempotent
        end
      end

    end
  end
end

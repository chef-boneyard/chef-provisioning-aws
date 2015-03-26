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
    end
  end
end

require 'spec_helper'

describe Chef::Resource::AwsCacheSubnetGroup do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC with an internet gateway and subnet" do
      aws_vpc "test_vpc" do
        cidr_block '10.0.0.0/24'
        internet_gateway true
      end

      aws_subnet "test_subnet" do
        vpc 'test_vpc'
        cidr_block "10.0.0.0/24"
      end

      it "aws_cache_subnet_group 'test-subnet-group' creates a cache subnet group" do
        expect_recipe {
          aws_cache_subnet_group 'test-subnet-group' do
            description 'Test Subnet Group'
            subnets [ 'test_subnet' ]
          end
        }.to create_an_aws_cache_subnet_group('test-subnet-group',
          vpc_id: test_vpc.aws_object.id,
          subnets: [
            { subnet_identifier: test_subnet.aws_object.id }
          ]
        ).and be_idempotent
      end
    end
  end
end

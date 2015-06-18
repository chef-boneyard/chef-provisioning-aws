require 'spec_helper'

describe Chef::Resource::AwsCacheCluster do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC with an internet gateway and subnet" do
      aws_vpc "test_vpc" do
        cidr_block '10.0.0.0/24'
        internet_gateway true
      end

      aws_subnet "test_subnet" do
        vpc 'test_vpc'
        availability_zone 'us-east-1a'
        cidr_block "10.0.0.0/24"
      end

      aws_cache_subnet_group 'test-ec' do
        description 'Test Subnet Gruop'
        subnets [ 'public-test' ]
      end

      aws_security_group 'test-sg' do
        vpc 'test_vpc'
      end

      it "aws_cache_cluster 'test_ec_cluster' creates an elasticache cluster" do
        expect_recipe {
          aws_cache_cluster 'test_ec_cluster' do
            az_mode 'single-az'
            number_nodes 2
            node_type 'cache.t2.micro'
            engine 'memcached'
            engine_version '1.4.14'
            security_groups ['test-sg']
            subnet_group_name 'test-ec'
          end
        }.to create_an_aws_cache_cluster("test_ec_cluster").and be_idempotent
      end
    end
  end
end

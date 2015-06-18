require 'spec_helper'

describe Chef::Resource::AwsCacheReplicationGroup do
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

      it "aws_cache_replication_group 'test_repl_group' creates an elasticache replication group" do
        expect_recipe {
          aws_cache_replication_group "test_repl_group" do
              description "my fancy group"
              node_type 'cache.t2.micro'
              engine 'memcached'
              engine_version '1.4.14'
              security_groups ['test-sg']
          end
        }.to create_an_aws_cache_replication_group("test_repl_group", {}).and be_idempotent
      end
    end
  end
end

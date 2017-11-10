require 'spec_helper'

describe Chef::Resource::AwsCacheCluster, :super_slow do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC, subnet, subnet_group and security_group" do
      after(:context) do
        # Cache Cluster takes around 7 minutes to get deleted
        # and all the dependent resources can be deleted after that only.
        # Hence waiting for 8 minutes.
        sleep(480)
        converge {
          aws_cache_subnet_group 'test-subnet-group' do
            action :destroy
          end

          aws_vpc "test_vpc" do
            action :purge
          end
        }
      end

      it "aws_cache_cluster 'TestRedisCluster' creates a cache cluster" do
        converge {
          aws_vpc "test_vpc" do
            cidr_block '10.0.0.0/24'
            internet_gateway true
          end

          aws_subnet "test_subnet" do
            vpc 'test_vpc'
            cidr_block "10.0.0.0/24"
          end

          aws_cache_subnet_group 'test-subnet-group' do
            description 'Test Subnet Group'
            subnets [ 'test_subnet' ]
          end

          aws_security_group 'test_sg' do
            vpc 'test_vpc'
          end
        }

        expect_recipe {
          aws_cache_cluster 'TestRedisCluster' do
            az_mode 'single-az'
            engine 'redis'
            engine_version '3.2.6'
            node_type 'cache.t2.micro'
            number_nodes 1
            security_groups 'test_sg'
            subnet_group_name 'test-subnet-group'
          end
        }.to create_an_aws_cache_cluster('TestRedisCluster',
          cache_cluster_id: "testrediscluster",
          cache_node_type: "cache.t2.micro",
          engine: "redis",
          engine_version: "3.2.6",
          num_cache_nodes: 1,
          pending_modified_values: {},
          cache_security_groups: [],
          cache_parameter_group:
            {cache_parameter_group_name: "default.redis3.2", parameter_apply_status: "in-sync", cache_node_ids_to_reboot: []},
          cache_subnet_group_name: "test-subnet-group"
          ).and be_idempotent
      end
    end
  end
end

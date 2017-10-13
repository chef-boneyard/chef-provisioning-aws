require 'spec_helper'
require 'aws-sdk'
require 'set'

describe Chef::Resource::AwsRdsSubnetGroup do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC with an internet gateway and subnet" do

      #region = ENV['AWS_TEST_DRIVER'][5..-1]

      azs = []
      driver.ec2.describe_availability_zones.availability_zones.each do |az|
        azs << az
      end
      az_1 = azs[0].zone_name
      az_2 = azs[1].zone_name

      aws_vpc "test_vpc" do
        cidr_block '10.0.0.0/24'
        internet_gateway true
      end

      aws_subnet "test_subnet" do
        vpc 'test_vpc'
        cidr_block "10.0.0.0/26"
        availability_zone az_1
      end

      aws_subnet "test_subnet_2" do
        vpc 'test_vpc'
        cidr_block "10.0.0.64/26"
        availability_zone az_2
      end

      it "creates a database subnet group containing multiple subnets" do
        expect_recipe {
          aws_rds_subnet_group "test-db-subnet-group" do
            description "some_description"
            subnets ["test_subnet", test_subnet_2.aws_object.id]
          end
        }.to create_an_aws_rds_subnet_group("test-db-subnet-group",
                                              :db_subnet_group_description => "some_description",
                                              :subnets => Set.new([ {:subnet_status => "Active",
                                                                     :subnet_identifier => test_subnet_2.aws_object.id,
                                                                     :subnet_availability_zone => {:name => az_2}},
                                                                    {:subnet_status => "Active",
                                                                     :subnet_identifier => test_subnet.aws_object.id,
                                                                     :subnet_availability_zone => {:name => az_1}}])
                                           ).and be_idempotent
      end

      it "creates aws_rds_subnet_group tags" do
        expect_recipe {
          aws_rds_subnet_group "test-db-subnet-group" do
            description "some_description"
            subnets ["test_subnet", test_subnet_2.aws_object.id]
            aws_tags key1: 'value'
          end
        }.to create_an_aws_rds_subnet_group("test-db-subnet-group")
        .and have_aws_rds_subnet_group_tags("test-db-subnet-group",
          {
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        aws_rds_subnet_group "test-db-subnet-group" do
          description "some_description"
          subnets ["test_subnet", test_subnet_2.aws_object.id]
          aws_tags key1: 'value'
        end

        it "updates aws_rds_subnet_group tags" do
          expect_recipe {
            aws_rds_subnet_group "test-db-subnet-group" do
              description "some_description"
              subnets ["test_subnet", test_subnet_2.aws_object.id]
              aws_tags key1: "value2", key2: ''
            end
          }.to have_aws_rds_subnet_group_tags("test-db-subnet-group",
            {
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_rds_subnet_group tags" do
          expect_recipe {
            aws_rds_subnet_group "test-db-subnet-group" do
              description "some_description"
              subnets ["test_subnet", test_subnet_2.aws_object.id]
              aws_tags({})
            end
          }.to have_aws_rds_subnet_group_tags("test-db-subnet-group", {}
          ).and be_idempotent
        end
      end

    end
  end
end

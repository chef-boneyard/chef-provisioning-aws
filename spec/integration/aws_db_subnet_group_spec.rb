require 'spec_helper'
require 'aws'

describe Chef::Resource::AwsDbSubnetGroup do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC with an internet gateway and subnet" do

      #region = ENV['AWS_TEST_DRIVER'][5..-1]
      
      aws_vpc "test_vpc" do
        cidr_block '10.0.0.0/24'
        internet_gateway true
      end

      subnet1 = aws_subnet "test_subnet" do
        vpc 'test_vpc'
        cidr_block "10.0.0.0/26"
        availability_zone "us-east-1a"
      end

      aws_subnet "test_subnet_2" do
        vpc 'test_vpc'
        cidr_block "10.0.0.64/26"
        availability_zone "us-east-1d"
      end

      it "creates a database subnet group containing multiple subnets" do
        expect_recipe {
          aws_db_subnet_group "test-db-subnet-group" do
            db_subnet_group_description "some_description"
            subnet_ids [test_subnet.aws_object.id, test_subnet_2.aws_object.id]
          end
        }.to create_an_aws_db_subnet_group("test-db-subnet-group",
                                              :db_subnet_group_description => "some_description",
                                              :subnets => [
                                                           {:subnet_status => "Active",
                                                            :subnet_identifier => test_subnet_2.aws_object.id,
                                                            :subnet_availability_zone => {:name =>"us-east-1d"}},
                                                           {:subnet_status => "Active",
                                                            :subnet_identifier => test_subnet.aws_object.id,
                                                            :subnet_availability_zone => {:name =>"us-east-1a"}}
                                              ]
                                             ).and be_idempotent
      end
      
    end
  end
end

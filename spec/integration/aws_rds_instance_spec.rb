require 'spec_helper'

describe Chef::Resource::AwsRdsInstance do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a connection to AWS, a VPC, two subnets, and a db subnet group" do

      azs = []
      driver.ec2.availability_zones.each do |az|
        azs << az
      end
      az_1 = azs[0].name
      az_2 = azs[1].name

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

      aws_rds_subnet_group "test-db-subnet-group" do
        description "some_description"
        subnets ["test_subnet", test_subnet_2.aws_object.id]
      end

      it "aws_rds_instance 'test-rds-instance' creates an rds instance that can parse the aws_rds_subnet_group" do
        expect_recipe {
          aws_rds_instance "test-rds-instance" do
            engine "postgres"
            publicly_accessible false
            db_instance_class "db.t1.micro"
            master_username "thechief"
            master_user_password "securesecure" # 2x security
            multi_az false
            db_subnet_group_name "test-db-subnet-group"
          end
        }.to create_an_aws_rds_instance('test-rds-instance',
                                        engine: 'postgres',
                                        # Can't assert these two as the v1 SDK has no method
                                        # that exposes it :(
                                        # publicly_accessible: false,
                                        # db_subnet_group_name: "test-db-subnet-group"
                                        multi_az: false,
                                        db_instance_class: "db.t1.micro",
                                        master_username: "thechief",
                                       ).and be_idempotent
      end

      it "aws_rds_instance prefers explicit options" do
        expect_recipe {
          aws_rds_instance "test-rds-instance2" do
            engine "postgres"
            publicly_accessible false
            db_instance_class "db.t1.micro"
            master_username "thechief"
            master_user_password "securesecure"
            multi_az false
            additional_options(multi_az: true)
          end
        }.to create_an_aws_rds_instance('test-rds-instance2',
                                        engine: 'postgres',
                                        multi_az: false,
                                        db_instance_class: "db.t1.micro",
                                        master_username: "thechief")

      end

    end
  end
end

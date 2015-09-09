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
        cidr_block '10.0.5.0/24'
        internet_gateway true
      end

      aws_subnet "test_subnet" do
        vpc 'test_vpc'
        cidr_block "10.0.5.0/26"
        availability_zone az_1
      end

      aws_subnet "test_subnet_2" do
        vpc 'test_vpc'
        cidr_block "10.0.5.64/26"
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
            allocated_storage 5
            db_subnet_group_name "test-db-subnet-group"
          end
        }.to create_an_aws_rds_instance('test-rds-instance',
                                        engine: 'postgres',
                                        multi_az: false,
                                        db_instance_class: "db.t1.micro",
                                        master_username: "thechief",
                                       ).and be_idempotent
        i = driver.rds.client.describe_db_instances(:db_instance_identifier => "test-rds-instance")[:db_instances].first
        expect(i[:db_subnet_group][:db_subnet_group_name]).to eq("test-db-subnet-group")
        expect(i[:publicly_accessible]).to eq(false)
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
            allocated_storage 5
            additional_options(multi_az: true, backup_retention_period: 2)
          end
        }.to create_an_aws_rds_instance('test-rds-instance2',
                                        engine: 'postgres',
                                        multi_az: false,
                                        db_instance_class: "db.t1.micro",
                                        master_username: "thechief",
                                        backup_retention_period: 2)

      end

      tagging_id = Random.rand(1000)

      it "creates aws_rds_instance tags" do
        expect_recipe {
          aws_rds_instance "test-rds-instance-tagging-#{tagging_id}" do
            aws_tags key1: "value"
            allocated_storage 5
            db_instance_class "db.t1.micro"
            engine "postgres"
            master_username "thechief"
            master_user_password "securesecure"
          end
        }.to create_an_aws_rds_instance("test-rds-instance-tagging-#{tagging_id}")
        .and have_aws_rds_instance_tags("test-rds-instance-tagging-#{tagging_id}",
          {
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      # if we use let, the tagging_id method is not available in the context block
      tagging_id = Random.rand(1000)

      context "with existing tags" do
        aws_rds_instance "test-rds-instance-tagging-#{tagging_id}" do
          aws_tags key1: "value"
          allocated_storage 5
          db_instance_class "db.t1.micro"
          engine "postgres"
          master_username "thechief"
          master_user_password "securesecure"
        end

        it "updates aws_rds_instance tags" do
          expect_recipe {
            aws_rds_instance "test-rds-instance-tagging-#{tagging_id}" do
              aws_tags key1: "value2", key2: nil
              allocated_storage 5
              db_instance_class "db.t1.micro"
              engine "postgres"
              master_username "thechief"
              master_user_password "securesecure"
            end
          }.to have_aws_rds_instance_tags("test-rds-instance-tagging-#{tagging_id}",
            {
              'key1' => 'value2',
              'key2' => nil
            }
          ).and be_idempotent
        end

        it "removes all aws_rds_instance tags" do
          expect_recipe {
            aws_rds_instance "test-rds-instance-tagging-#{tagging_id}" do
              aws_tags {}
              allocated_storage 5
              db_instance_class "db.t1.micro"
              engine "postgres"
              master_username "thechief"
              master_user_password "securesecure"
            end
          }.to have_aws_rds_instance_tags("test-rds-instance-tagging-#{tagging_id}", {}
          ).and be_idempotent
        end
      end

    end
  end
end

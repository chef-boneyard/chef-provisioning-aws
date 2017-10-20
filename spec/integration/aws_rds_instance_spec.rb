require 'spec_helper'

describe Chef::Resource::AwsRdsInstance do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a connection to AWS, a VPC, two subnets, a db subnet group, and a db parameter group" do

      azs = []
      driver.ec2.describe_availability_zones.availability_zones.each do |az|
        azs << az
      end
      az_1 = azs[0].zone_name
      az_2 = azs[1].zone_name
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

      aws_rds_parameter_group "test-db-parameter-group" do
        db_parameter_group_family "postgres9.6"
        description "testing provisioning"
        parameters [{:parameter_name => "max_connections", :parameter_value => "250", :apply_method => "pending-reboot"}]
      end

      it "aws_rds_instance 'test-rds-instance' creates an rds instance that can parse the aws_rds_subnet_group and aws_rds_parameter_group" do
        expect_recipe {
          aws_rds_instance "test-rds-instance" do
            engine "postgres"
            publicly_accessible false
            db_instance_class "db.t2.micro"
            master_username "thechief"
            master_user_password "securesecure" # 2x security
            multi_az false
            allocated_storage 5
            db_subnet_group_name "test-db-subnet-group"
            db_parameter_group_name "test-db-parameter-group"
          end
        }.to create_an_aws_rds_instance('test-rds-instance',
                                        engine: 'postgres',
                                        multi_az: false,
                                        db_instance_class: "db.t2.micro",
                                        master_username: "thechief",
                                       ).and be_idempotent
        r = driver.rds_resource.db_instance("test-rds-instance")
        expect(r.db_subnet_group.db_subnet_group_name).to eq("test-db-subnet-group")
        expect(r.db_parameter_groups.first.db_parameter_group_name).to eq("test-db-parameter-group")
        expect(r.publicly_accessible).to eq(false)
      end

      it "aws_rds_instance prefers explicit options" do
        expect_recipe {
          aws_rds_instance "test-rds-instance2" do
            engine "postgres"
            publicly_accessible false
            db_instance_class "db.t2.micro"
            master_username "thechief"
            master_user_password "securesecure"
            multi_az false
            allocated_storage 5
            additional_options(multi_az: true, backup_retention_period: 2)
          end
        }.to create_an_aws_rds_instance('test-rds-instance2',
                                        engine: 'postgres',
                                        multi_az: false,
                                        db_instance_class: "db.t2.micro",
                                        master_username: "thechief",
                                        backup_retention_period: 2)

      end

      tagging_id = Random.rand(1000)

      it "creates aws_rds_instance tags" do
        expect_recipe {
          aws_rds_instance "test-rds-instance-tagging-#{tagging_id}" do
            aws_tags key1: "value"
            allocated_storage 5
            db_instance_class "db.t2.micro"
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
          db_instance_class "db.t2.micro"
          engine "postgres"
          master_username "thechief"
          master_user_password "securesecure"
        end

        it "updates aws_rds_instance tags" do
          expect_recipe {
            aws_rds_instance "test-rds-instance-tagging-#{tagging_id}" do
              aws_tags key1: "value1", key2: "value2"
              allocated_storage 5
              db_instance_class "db.t2.micro"
              engine "postgres"
              master_username "thechief"
              master_user_password "securesecure"
            end
          }.to have_aws_rds_instance_tags("test-rds-instance-tagging-#{tagging_id}",
            {
              'key1' => 'value1',
              'key2' => 'value2'
            }
          ).and be_idempotent
        end

        it "removes all aws_rds_instance tags" do
          expect_recipe {
            aws_rds_instance "test-rds-instance-tagging-#{tagging_id}" do
              aws_tags({})
              allocated_storage 5
              db_instance_class "db.t2.micro"
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

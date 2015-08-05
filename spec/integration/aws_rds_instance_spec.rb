require 'spec_helper'

describe Chef::Resource::AwsRdsInstance do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a connection to AWS" do
      it "aws_rds_instance 'test-rds-instance' creates an rds instance" do
        expect_recipe {
          aws_rds_instance "test-rds-instance" do
            engine "postgres"
            publicly_accessible false
            db_instance_class "db.t1.micro"
            master_username "thechief"
            master_user_password "securesecure" # 2x security
            multi_az false
          end
        }.to create_an_aws_rds_instance('test-rds-instance',
                                        engine: 'postgres',
                                        # Can't assert this as the v1 SDK has no method
                                        # that exposes it :(
                                        # publicly_accessible: false,
                                        multi_az: false,
                                        db_instance_class: "db.t1.micro",
                                        master_username: "thechief"
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

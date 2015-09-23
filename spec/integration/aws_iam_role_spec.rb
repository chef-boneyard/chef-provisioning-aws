require 'spec_helper'
require 'securerandom'

def mk_role_name
  name_postfix = SecureRandom.hex(8)
  "chef_provisioning_test_iam_role_#{name_postfix}"
end

def ec2_role_policy
<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
end

def rds_role_policy
<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1441787971000",
      "Effect": "Allow",
      "Action": [
          "rds:*"
      ],
      "Resource": [
          "*"
      ]
    }
  ]
}
EOF
end

def iam_role_policy
<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:*",
      "Resource": "*"
    }
  ]
}
EOF
end

describe Chef::Resource::AwsIamRole do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: "foo", server_scope: :context do
    with_aws "when connected to AWS" do

      context "Basic IAM role creation" do
        role_name = mk_role_name

        it "aws_iam_role '#{role_name}' creates an IAM role" do

          expect_recipe {
            aws_iam_role role_name do
              assume_role_policy_document ec2_role_policy
            end
          }.to create_an_aws_iam_role(role_name).and be_idempotent
        end

      end

      context "create role with instance profile" do
        role_name = mk_role_name

        aws_iam_role role_name do
          assume_role_policy_document ec2_role_policy
        end

        it "aws_iam_instance_profile '#{role_name}' creates an instance profile with role" do
          expect_recipe {

            aws_iam_instance_profile role_name do
              role role_name
            end

          }.to create_an_aws_iam_instance_profile(role_name).and be_idempotent

          role = driver.iam_resource.role(role_name)

          expect(role.instance_profiles.count).to eq 1
          expect(role.instance_profiles.first.name).to eq(role_name)
        end
      end

      context "delete role with instance profile" do
        role_name = mk_role_name

        aws_iam_role role_name do
          assume_role_policy_document ec2_role_policy
        end

        aws_iam_instance_profile role_name do
          role role_name
        end

        it "deletes the role '#{role_name}'" do
          r = recipe {
            aws_iam_role role_name do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_iam_role(role_name).and be_idempotent
        end

        it "deletes the instance profile '#{role_name}'" do
          r = recipe {
            aws_iam_instance_profile role_name do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_iam_instance_profile(role_name).and be_idempotent
        end
      end

      context "delete role with role policy" do
        role_name = mk_role_name

        aws_iam_role role_name do
          assume_role_policy_document ec2_role_policy
        end

        it "deletes the role policy 'rds_full_access'" do
          recipe {
            aws_iam_role_policy "rds_full_access" do
              role role_name
              policy_document rds_role_policy
            end

            aws_iam_role_policy "rds_full_access" do
              role role_name
              action :destroy
            end
          }
          role = driver.iam_resource.role(role_name)
          policy = role.policies.first

          expect(role.policies.count).to eq 0
        end

      end

      context "create role with role policy" do
        role_name = mk_role_name

        it "aws_iam_role_policy 'rds_full_access' creates a role policy for role" do
          expect_recipe {

            aws_iam_role role_name do
              assume_role_policy_document ec2_role_policy
            end

            aws_iam_role_policy "rds_full_access" do
              role role_name
              policy_document rds_role_policy
            end

          }.to create_an_aws_iam_role(role_name).and be_idempotent

          role = driver.iam_resource.role(role_name)

          policy = role.policies.first

          expect(role.policies.count).to eq 1
          expect(policy.name).to eq("rds_full_access")
        end
      end

      context "create role with role policy and update role policy" do
        role_name = mk_role_name

        it "aws_iam_role_policy 'rds_full_access' updates a role policy for role" do

          expect_recipe {
            aws_iam_role role_name do
              assume_role_policy_document ec2_role_policy
            end

            aws_iam_role_policy "my_role_policy" do
              role role_name
              policy_document rds_role_policy
            end

            aws_iam_role_policy "my_role_policy" do
              role role_name
              policy_document iam_role_policy
            end
          }.to create_an_aws_iam_role(role_name)

          role = driver.iam_resource.role(role_name)

          policy = role.policies.first

          expect(URI.decode(policy.policy_document)).to eq(iam_role_policy)
        end
      end

    end

  end
end

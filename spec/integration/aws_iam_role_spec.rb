require 'spec_helper'
require 'securerandom'

def ec2_principal
<<-EOF
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

def rds_principal
<<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "rds.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
end

def rds_role_policy
<<-EOF
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
<<-EOF
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

      let(:role_name) {
        name_postfix = SecureRandom.hex(8)
        "cp_test_iam_role_#{name_postfix}"
      }

      it "creates an aws_iam_role with minimum attributes" do
        expect_recipe {
          aws_iam_role role_name do
            assume_role_policy_document ec2_principal
          end
        }.to create_an_aws_iam_role(role_name) { |aws_object|
          expect(Chef::JSONCompat.parse(URI.decode(aws_object.assume_role_policy_document))).to eq(Chef::JSONCompat.parse(ec2_principal))
        }.and be_idempotent
      end

      it "creates an aws_iam_role with maximum attributes" do
        expect_recipe {
          aws_iam_role role_name do
            path "/"
            assume_role_policy_document ec2_principal
            inline_policies a: iam_role_policy
          end
        }.to create_an_aws_iam_role(role_name,
          path: "/",
          policies: [{name: "a"}]
        ) { |aws_object|
          expect(Chef::JSONCompat.parse(URI.decode(aws_object.assume_role_policy_document))).to eq(Chef::JSONCompat.parse(ec2_principal))
          expect(Chef::JSONCompat.parse(URI.decode(aws_object.policies.first.policy_document))).to eq(Chef::JSONCompat.parse(iam_role_policy))
        }.and be_idempotent
      end

      context "with an existing aws_iam_role" do
        # Doing this in a before(:each) block for 2 reasons:
        # 1) the context-level methods only destroy the item after the context is finished,
        #    and I want the tests to assert on a new item each example
        # 2) the let(:role_name) cannot be used at the context level, only at
        #    the example/before/after level
        before(:each) do
          converge {
            aws_iam_role role_name do
              path "/"
              assume_role_policy_document ec2_principal
              inline_policies a: iam_role_policy
            end
          }
        end

        after(:each) do
          converge {
            aws_iam_role role_name do
              action :destroy
            end
          }
        end


        it "updates all available fields" do
          expect_recipe {
            aws_iam_role role_name do
              assume_role_policy_document rds_principal
              inline_policies b: rds_role_policy
            end
          }.to create_an_aws_iam_role(role_name,
            path: "/",
            policies: [{name: "b"}]
          ) { |aws_object|
            expect(Chef::JSONCompat.parse(URI.decode(aws_object.assume_role_policy_document))).to eq(Chef::JSONCompat.parse(rds_principal))
            expect(Chef::JSONCompat.parse(URI.decode(aws_object.policies.first.policy_document))).to eq(Chef::JSONCompat.parse(rds_role_policy))
          }.and be_idempotent
        end

        it "clears inline_policies with an empty hash" do
          expect_recipe {
            aws_iam_role role_name do
              inline_policies Hash.new
            end
          }.to create_an_aws_iam_role(role_name,
            path: "/",
            policies: []
          ).and be_idempotent
        end

        it "deletes the aws_iam_role" do
          r = recipe {
            aws_iam_role role_name do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_iam_role(role_name)
          expect { driver.iam_client.list_role_policies(role_name: role_name).policy_names }.to raise_error(::Aws::IAM::Errors::NoSuchEntity)
        end
      end

    end

  end
end

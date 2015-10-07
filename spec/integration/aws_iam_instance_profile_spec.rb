require 'spec_helper'
require 'securerandom'

def mk_role_name
  name_postfix = SecureRandom.hex(8)
  "chef_provisioning_test_iam_role_#{name_postfix}"
end

def ec2_principal
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

describe Chef::Resource::AwsIamRole do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: "foo", server_scope: :context do
    with_aws "when connected to AWS" do

      let(:instance_name) {
        name_postfix = SecureRandom.hex(8)
        "cp_test_iam_instance_profile_#{name_postfix}"
      }

      it "creates an aws_iam_instance_profile with minimum attributes" do
        expect_recipe {
          aws_iam_instance_profile instance_name do
            path "/"
          end
        }.to create_an_aws_iam_instance_profile(instance_name,
          path: "/"
        ).and be_idempotent
      end

      context "with an existing aws_iam_role" do
        let(:role_name) {
          name_postfix = SecureRandom.hex(8)
          "cp_test_iam_role_#{name_postfix}"
        }

        # See aws_iam_role_spec.rb for explanation
        before(:each) do
          converge {
            aws_iam_role role_name do
              path "/"
              assume_role_policy_document ec2_principal
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

        it "creates an aws_iam_instance_profile with maximum attributes" do
          expect_recipe {
            aws_iam_instance_profile instance_name do
              path "/"
              role role_name
            end
          }.to create_an_aws_iam_instance_profile(instance_name,
            path: "/",
            roles: [{name: role_name}]
          ).and be_idempotent
        end

        context "with an existing aws_iam_instance_profile with an attached role" do
          before(:each) do
            converge {
              aws_iam_instance_profile instance_name do
                path "/"
                role role_name
              end
            }
          end

          after(:each) do
            converge {
              aws_iam_instance_profile instance_name do
                action :destroy
              end
            }
          end

          it "removes the relationship when the role is deleted" do
            expect_recipe {
              aws_iam_role role_name do
                action :destroy
              end
            }.to match_an_aws_iam_instance_profile(instance_name,
              roles: []
            ).and be_idempotent
          end

          it "removes the relationship when the instance_profile is deleted" do
            expect_recipe {
              aws_iam_instance_profile instance_name do
                action :destroy
              end
            }.to match_an_aws_iam_role(role_name,
              instance_profiles: []
            ).and be_idempotent
          end

          context "with a second aws_iam_role" do
            before(:each) do
              converge {
                aws_iam_role "#{role_name}2" do
                  path "/"
                  assume_role_policy_document ec2_principal
                end
              }
            end

            after(:each) do
              converge {
                aws_iam_instance_profile instance_name do
                  action :destroy
                end
              }
            end

            it "updates the attached role" do
              expect_recipe {
                aws_iam_instance_profile instance_name do
                  path "/"
                  role "#{role_name}2"
                end
              }.to update_an_aws_iam_instance_profile(instance_name,
                path: "/",
                roles: [{name: "#{role_name}2"}]
              ).and be_idempotent
            end
          end

        end
      end

    end

  end
end

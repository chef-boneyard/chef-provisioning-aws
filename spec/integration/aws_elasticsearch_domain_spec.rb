require 'spec_helper'

def policy(user)
  <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Sid": "test-policy",
      "Principal": {
        "AWS": "#{user}"
      },
      "Action": "es:*",
      "Resource": "*"
    }
  ]
}
EOF
end

def all_options_domain(name)
  aws_elasticsearch_domain name do
    instance_type "m4.large.elasticsearch"
    instance_count 2
    dedicated_master_enabled true
    dedicated_master_type "m4.large.elasticsearch"
    dedicated_master_count 2
    zone_awareness_enabled true
    ebs_enabled true
    volume_type "io1"
    volume_size 35
    iops 1000
    automated_snapshot_start_hour 2
    access_policies policy(driver.iam_client.get_user.user.arn)
    aws_tags key1: "value"
  end
end

describe Chef::Resource::AwsElasticsearchDomain do
  extend AWSSupport

  let(:all_options_result) do
    {created: true,
     elasticsearch_cluster_config: {
       instance_type: "m4.large.elasticsearch",
       instance_count: 2,
       dedicated_master_enabled: true,
       dedicated_master_type: "m4.large.elasticsearch",
       zone_awareness_enabled: true
     },
     ebs_options: {
       ebs_enabled: true,
       volume_size: 35,
       volume_type: "io1",
       iops: 1000
     },
     snapshot_options: {
       automated_snapshot_start_hour: 2
     }
    }
  end

  when_the_chef_12_server "exists", organization: "foo", server_scope: :context do
    with_aws "when connected to AWS" do
      time = DateTime.now.strftime('%Q')

      it "returns nil when aws_object is called for something that does not exist" do
        r = nil
        converge {
          r = aws_elasticsearch_domain "wont-exist" do
            action :nothing
          end
        }
        expect(r.aws_object).to eq(nil)
      end

      it "aws_elasticsearch_domain 'test-#{time}' creates a elasticsearch domain" do
        expect_recipe {
          all_options_domain("test-#{time}")
        }.to create_an_aws_elasticsearch_domain("test-#{time}", all_options_result).and be_idempotent
      end

      context "with an existing elasticsearch domain" do
        aws_elasticsearch_domain "test-#{time}-2" do
          ebs_enabled true
          volume_size 35
        end

        it "can update all options" do
          expect_recipe {
            all_options_domain("test-#{time}-2")
          }.to update_an_aws_elasticsearch_domain("test-#{time}-2", all_options_result)
        end

        it "updates the aws_tags" do
          expect_recipe {
            all_options_domain("test-#{time}-2")
          }.to have_aws_elasticsearch_domain_tags("test-#{time}-2", {'key1' => 'value'})
        end

        it "removes all aws_elasticsearch_domain tags" do
          expect_recipe {
            aws_elasticsearch_domain "test-#{time}-2" do
              aws_tags({})
            end
          }.to have_aws_elasticsearch_domain_tags("test-#{time}-2", {}).and be_idempotent
        end


        it "destroys an elasticsearch domain" do
          r = recipe {
            aws_elasticsearch_domain "test-#{time}-2" do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_elasticsearch_domain("test-#{time}-2")
        end
      end
    end
  end
end

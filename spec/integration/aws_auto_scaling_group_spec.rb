require 'spec_helper'

describe Chef::Resource::AwsAutoScalingGroup do
  extend AWSSupport

  when_the_chef_12_server 'exists', organization: 'foo', server_scope: :context do
    with_aws 'When connected to AWS' do
      # Select an amazon linux ami based upon region
      ami = {
        'eu-west-1' => 'ami-3850624c',
        'eu-central-1' => 'ami-993383ea',
        'us-east-1' => 'ami-e024bf89',
        'us-west-1' => 'ami-951945d0',
        'us-west-2' => 'ami-16fd7026',
        'ap-northeast-1' => 'ami-dcfa4edd',
        'ap-northeast-2' => 'ami-7308c51d',
        'ap-southeast-1' => 'ami-74dda626',
        'ap-southeast-2' => 'ami-b5990e8f',
        'sa-east-1' => 'ami-3e3be423'
      }[driver.region]

      aws_launch_configuration 'test_config' do
        image ami
        instance_type 't1.micro'
      end

      aws_sns_topic 'test_topic'

      it "aws_auto_scaling_group 'test_group' creates an auto scaling group" do
        expect_recipe {
          aws_auto_scaling_group 'test_group' do
            launch_configuration 'test_config'
            availability_zones ["#{driver.region}a"]
            min_size 1
            max_size 2
          end
        }.to create_an_aws_auto_scaling_group(
          'test_group').and be_idempotent
      end

      it "aws_auto_scaling_group 'test_group_with_policy' creates an auto scaling group" do
        expect_recipe {
          aws_auto_scaling_group 'test_group_with_policy' do
            launch_configuration 'test_config'
            availability_zones ["#{driver.region}a"]
            min_size 1
            max_size 2
            notification_configurations [{
              topic: driver.build_arn(service: 'sns', resource: 'test_topic'),
              types: [
                'autoscaling:EC2_INSTANCE_LAUNCH',
                'autoscaling:EC2_INSTANCE_TERMINATE'
              ]
            }]
            scaling_policies(
              test_policy: {
                adjustment_type: 'ChangeInCapacity',
                scaling_adjustment: 1
              }
            )
          end
        }.to create_an_aws_auto_scaling_group(
          'test_group_with_policy').and be_idempotent
      end

      # test_public_subnet
      context "when referencing a subnet" do
        purge_all
        setup_public_vpc
        it "creates an aws_auto_scaling_group" do
          expect_recipe {
            aws_auto_scaling_group 'test_group' do
              launch_configuration 'test_config'
              # availability_zones ["#{driver.region}a"]
              min_size 1
              max_size 2
              options({
                subnets: 'test_public_subnet'
              })
            end
          }.to create_an_aws_auto_scaling_group('test_group',
            vpc_zone_identifier: test_public_subnet.aws_object.id
          ).and be_idempotent
        end
      end

      it "creates aws_auto_scaling_group tags" do
        expect_recipe {
          aws_auto_scaling_group 'test_group_with_policy' do
            launch_configuration 'test_config'
            availability_zones ["#{driver.region}a"]
            min_size 1
            max_size 2
            aws_tags key1: "value"
          end
        }.to create_an_aws_auto_scaling_group('test_group_with_policy'
        ).and have_aws_auto_scaling_group_tags('test_group_with_policy',
          {
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        aws_auto_scaling_group 'test_group_with_policy' do
          launch_configuration 'test_config'
          availability_zones ["#{driver.region}a"]
          min_size 1
          max_size 2
          aws_tags key1: "value"
        end

        it "updates aws_auto_scaling_group tags" do
          expect_recipe {
            aws_auto_scaling_group 'test_group_with_policy' do
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_auto_scaling_group_tags('test_group_with_policy',
            {
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_network_acl tags" do
          expect_recipe {
            aws_auto_scaling_group 'test_group_with_policy' do
              aws_tags({})
            end
          }.to have_aws_auto_scaling_group_tags('test_group_with_policy',
            {}
          ).and be_idempotent
        end
      end

    end
  end
end

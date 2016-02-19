require 'spec_helper'

describe Chef::Resource::AwsAutoScalingGroup do
  extend AWSSupport

  when_the_chef_12_server 'exists', organization: 'foo', server_scope: :context do
    with_aws 'When connected to AWS' do
      aws_launch_configuration 'test_config' do
        image 'ami-993383ea'
        instance_type 't1.micro'
      end

      it "aws_auto_scaling_group 'test_group' creates an auto scaling group" do
        expect_recipe {
          aws_auto_scaling_group 'test_group' do
            launch_configuration 'test_config'
            availability_zones ["#{driver.aws_config.region}a"]
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
            availability_zones ["#{driver.aws_config.region}a"]
            min_size 1
            max_size 2
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
    end
  end
end

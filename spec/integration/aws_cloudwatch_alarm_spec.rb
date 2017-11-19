require 'spec_helper'

describe Chef::Resource::AwsCloudwatchAlarm do
  extend AWSSupport

  when_the_chef_12_server 'exists', organization: 'foo', server_scope: :context do
    with_aws 'When connected to AWS' do

      aws_sns_topic 'mytesttopic1'
      aws_sns_topic 'mytesttopic2'

      it "creates an aws_cloudwatch_alarm with minimum properties" do
        expect_recipe {
          aws_cloudwatch_alarm 'my-test-alert' do
            namespace 'AWS/EC2'
            metric_name 'CPUUtilization'
            comparison_operator 'GreaterThanThreshold'
            evaluation_periods 1
            period 60
            statistic 'Average'
            threshold 80
          end
        }.to create_an_aws_cloudwatch_alarm('my-test-alert',
          namespace: 'AWS/EC2',
          metric_name: 'CPUUtilization',
          comparison_operator: 'GreaterThanThreshold',
          evaluation_periods: 1,
          period: 60,
          statistic: 'Average',
          threshold: 80,
          actions_enabled: true # this is true by default
        ).and be_idempotent
      end

      it "creates an aws_cloudwatch_alarm with maximum properties" do
        expect_recipe {
          aws_cloudwatch_alarm 'my-test-alert' do
            namespace 'AWS/EC2'
            metric_name 'CPUUtilization'
            comparison_operator 'GreaterThanThreshold'
            evaluation_periods 1
            period 60
            statistic 'Average'
            threshold 80
            dimensions([
              {
                name: "foo1",
                value: "bar1"
              },
              {
                name: "foo2",
                value: "bar2"
              }
            ])
            insufficient_data_actions ['mytesttopic1']
            ok_actions ['mytesttopic1']
            alarm_actions ['mytesttopic1']
            actions_enabled false
            alarm_description "description"
            unit "Percent"
          end
        }.to create_an_aws_cloudwatch_alarm('my-test-alert',
          namespace: 'AWS/EC2',
          metric_name: 'CPUUtilization',
          comparison_operator: 'GreaterThanThreshold',
          evaluation_periods: 1,
          period: 60,
          statistic: 'Average',
          threshold: 80,
          dimensions: [
            {
              name: "foo1",
              value: "bar1"
            },
            {
              name: "foo2",
              value: "bar2"
            }
          ],
          insufficient_data_actions: [mytesttopic1.aws_object.attributes["TopicArn"]],
          ok_actions: [mytesttopic1.aws_object.attributes["TopicArn"]],
          alarm_actions: [mytesttopic1.aws_object.attributes["TopicArn"]],
          actions_enabled: false,
          alarm_description: "description",
          unit: "Percent",
        ).and be_idempotent
      end

      context "with an existing minimum cloudwatch alarm" do
        aws_cloudwatch_alarm 'my-test-alert' do
          namespace 'AWS/EC2'
          metric_name 'CPUUtilization'
          comparison_operator 'GreaterThanThreshold'
          evaluation_periods 1
          period 60
          statistic 'Average'
          threshold 80
        end

        it "updates an aws_cloudwatch_alarm with maximum properties" do
          expect_recipe {
            aws_cloudwatch_alarm 'my-test-alert' do
              namespace 'AWS/EC2'
              metric_name 'CPUUtilization'
              comparison_operator 'GreaterThanThreshold'
              evaluation_periods 1
              period 60
              statistic 'Average'
              threshold 80
              dimensions([
                {
                  name: "foo1",
                  value: "bar1"
                },
                {
                  name: "foo2",
                  value: "bar2"
                }
              ])
              insufficient_data_actions ['mytesttopic1']
              ok_actions ['mytesttopic1']
              alarm_actions ['mytesttopic1']
              actions_enabled false
              alarm_description "description"
              unit "Percent"
            end
          }.to update_an_aws_cloudwatch_alarm('my-test-alert',
            namespace: 'AWS/EC2',
            metric_name: 'CPUUtilization',
            comparison_operator: 'GreaterThanThreshold',
            evaluation_periods: 1,
            period: 60,
            statistic: 'Average',
            threshold: 80,
            dimensions: [
              {
                name: "foo1",
                value: "bar1"
              },
              {
                name: "foo2",
                value: "bar2"
              }
            ],
            insufficient_data_actions: [mytesttopic1.aws_object.attributes["TopicArn"]],
            ok_actions: [mytesttopic1.aws_object.attributes["TopicArn"]],
            alarm_actions: [mytesttopic1.aws_object.attributes["TopicArn"]],
            actions_enabled: false,
            alarm_description: "description",
            unit: "Percent",
          ).and be_idempotent
        end

      end

      context "with an existing maximum cloudwatch alarm" do
        aws_cloudwatch_alarm 'my-test-alert' do
          namespace 'AWS/EC2'
          metric_name 'CPUUtilization'
          comparison_operator 'GreaterThanThreshold'
          evaluation_periods 1
          period 60
          statistic 'Average'
          threshold 80
          dimensions([
            {
              name: "foo1",
              value: "bar1"
            },
            {
              name: "foo2",
              value: "bar2"
            }
          ])
          insufficient_data_actions ['mytesttopic1']
          ok_actions ['mytesttopic1']
          alarm_actions ['mytesttopic1']
          actions_enabled false
          alarm_description "description"
          unit "Percent"
        end

        it "updates all updateable attributes" do
          expect_recipe {
            aws_cloudwatch_alarm 'my-test-alert' do
              namespace 'AWS/S3'
              metric_name 'foo'
              comparison_operator 'LessThanThreshold'
              evaluation_periods 2
              period 120
              statistic 'Maximum'
              threshold 70
              dimensions([
                {
                  name: "foo3",
                  value: "bar3"
                }
              ])
              insufficient_data_actions ['mytesttopic2']
              ok_actions ['mytesttopic1', 'mytesttopic2']
              alarm_actions ['mytesttopic2']
              actions_enabled true
              alarm_description "description2"
              unit "Bits"
            end
          }.to update_an_aws_cloudwatch_alarm('my-test-alert',
            namespace: 'AWS/S3',
            metric_name: 'foo',
            comparison_operator: 'LessThanThreshold',
            evaluation_periods: 2,
            period: 120,
            statistic: 'Maximum',
            threshold: 70,
            dimensions: [
              {
                name: "foo3",
                value: "bar3"
              }
            ],
            insufficient_data_actions: [mytesttopic2.aws_object.attributes["TopicArn"]],
            ok_actions: Set[mytesttopic1.aws_object.attributes["TopicArn"], mytesttopic2.aws_object.attributes["TopicArn"]],
            alarm_actions: [mytesttopic2.aws_object.attributes["TopicArn"]],
            actions_enabled: true,
            alarm_description: "description2",
            unit: "Bits",
          ).and be_idempotent
        end

        it "updates only the specified properties" do
          expect_recipe {
            aws_cloudwatch_alarm 'my-test-alert' do
              unit "Gigabytes"
            end
          }.to update_an_aws_cloudwatch_alarm('my-test-alert',
          namespace: 'AWS/S3',
          metric_name: 'foo',
          comparison_operator: 'LessThanThreshold',
          evaluation_periods: 2,
          period: 120,
          statistic: 'Maximum',
          threshold: 70,
          dimensions: [
            {
              name: "foo3",
              value: "bar3"
            }
          ],
          insufficient_data_actions: [mytesttopic2.aws_object.attributes["TopicArn"]],
          ok_actions: Set[mytesttopic1.aws_object.attributes["TopicArn"], mytesttopic2.aws_object.attributes["TopicArn"]],
          alarm_actions: [mytesttopic2.aws_object.attributes["TopicArn"]],
          actions_enabled: true,
          alarm_description: "description2",
          unit: "Gigabytes",
          ).and be_idempotent
        end

        it "clears out all clearable arrays" do
          expect_recipe {
            aws_cloudwatch_alarm 'my-test-alert' do
              dimensions []
              insufficient_data_actions []
              ok_actions []
              alarm_actions []
            end
          }.to create_an_aws_cloudwatch_alarm('my-test-alert',
            namespace: 'AWS/S3',
            metric_name: 'foo',
            comparison_operator: 'LessThanThreshold',
            evaluation_periods: 2,
            period: 120,
            statistic: 'Maximum',
            threshold: 70,
            dimensions: [],
            insufficient_data_actions: [],
            ok_actions: [],
            alarm_actions: [],
            actions_enabled: true,
            alarm_description: "description2",
            unit: "Gigabytes",
          ).and be_idempotent
        end
      end

    end
  end
end

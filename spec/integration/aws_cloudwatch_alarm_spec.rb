require 'spec_helper'

describe Chef::Resource::AwsCloudwatchAlarm do
  extend AWSSupport

  when_the_chef_12_server 'exists', organization: 'foo', server_scope: :context do
    with_aws 'When connected to AWS' do
      it 'creates the cloudwatch alarm' do
        r = recipe {
          aws_cloudwatch_alarm 'my-test-alert' do
            namespace 'AWS/EC2'
            metric_name 'CPUUtilization'
            comparison_operator 'GreaterThanThreshold'
            evaluation_periods 1
            period 60
            statistic 'Average'
            threshold 80
          end
        }
        expect(r).to create_an_aws_cloudwatch_alarm(
          'my-test-alert').and be_idempotent
      end

      describe 'delete a cloudwatch alarm' do
        with_converge {
          aws_cloudwatch_alarm 'my-test-alert' do
            namespace 'AWS/ELB'
            metric_name 'Latency'
            comparison_operator 'GreaterThanThreshold'
            evaluation_periods 1
            period 60
            statistic 'Average'
            threshold 4
          end
        }

        it 'deletes the cloudwatch alarm' do
          r = recipe {
            aws_cloudwatch_alarm 'my-test-alert' do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_cloudwatch_alarm('my-test-alert')
        end
      end
    end
  end
end

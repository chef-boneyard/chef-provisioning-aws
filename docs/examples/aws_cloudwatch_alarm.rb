# A simple alarm publishing notifications to an SNS topic
# which could potentially have email, sms or other subscriptions
topic = aws_sns_topic 'my-test-topic'

aws_cloudwatch_alarm 'Test Alert' do
  namespace 'AWS/EC2'
  metric_name 'MyTestMetric'
  comparison_operator 'GreaterThanThreshold'
  evaluation_periods 1
  period 60
  statistic 'Average'
  threshold 80
  alarm_actions [topic.arn]
end

# More complicated example settings up an alarm to scale up and auto-scaling
# group if the CPU passes a certain threshold
aws_launch_configuration 'my-launch-config' do
  image 'ami-ca3b11af'
  instance_type 't2.micro'
end

scaling_group = aws_auto_scaling_group 'scaling_group' do
  desired_capacity 3
  min_size 1
  max_size 5
  launch_configuration 'my-launch-config'
  availability_zones ["#{driver.region}a"]
  scaling_policies(
    'my-scaling-policy' => {
      adjustment_type: 'ChangeInCapacity',
      scaling_adjustment: 2
    }
  )
end

aws_cloudwatch_alarm 'my-test-alert' do
  namespace 'AWS/EC2'
  metric_name 'CPUUtilization'
  comparison_operator 'GreaterThanThreshold'
  evaluation_periods 1
  period 60
  statistic 'Average'
  threshold 80
  alarm_actions lazy { [
    scaling_group.aws_object.policies().select{ |p| p.name == 'my-scaling-policy'}.first.policy_arn
  ] }
end

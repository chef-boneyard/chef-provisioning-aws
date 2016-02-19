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
aws_launch_config 'my-launch-config' do
  image 'ami-f0b11187'
  instance_type 't1.micro'
end

aws_auto_scaling_group 'my-auto-scaling-group' do
  desired_capacity 3
  min_size 1
  max_size 5
  launch_config 'my-launch-config'
end

policy = aws_scaling_policy 'my-scaling-policy' do
  auto_scaling_group 'my-auto-scaling-group'
  adjustment_type 'ChangeInCapacity'
  scaling_adjustment 2
end

aws_cloudwatch_alarm 'my-test-alert' do
  namespace 'AWS/EC2'
  metric_name 'CPUUtilization'
  comparison_operator 'GreaterThanThreshold'
  evaluation_periods 1
  period 60
  statistic 'Average'
  threshold 80
  alarm_actions [policy.arn]
end


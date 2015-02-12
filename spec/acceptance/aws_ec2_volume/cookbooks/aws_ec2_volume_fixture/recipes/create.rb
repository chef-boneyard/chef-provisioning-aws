include_recipe 'aws_ec2_volume_fixture'

aws_ec2_volume node['test'] do
  availability_zone 'us-west-2a'
  size 10
  volume_type :io1
  iops 300
end

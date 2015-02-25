include_recipe 'aws_ebs_volume_fixture'

aws_ebs_volume node['test'] do
  availability_zone 'us-west-2a'
  size 10
  volume_type :io1
  iops 300
end

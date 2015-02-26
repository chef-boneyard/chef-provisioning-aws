include_recipe 'aws_ebs_volume_fixture'

ebs_test_node = search(:node, "*:#{node['test']}").first

aws_ebs_volume node['test'] do
  action [:create, :attach]
  availability_zone 'us-west-2a'
  size 10
  volume_type :io1
  iops 300
  instance_id ebs_test_node[:ec2][:instance_id]
  device '/dev/xvdf'
end

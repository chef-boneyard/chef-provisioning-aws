include_recipe 'aws_ec2_volume_fixture'

ebs_test_node = search(:node, "*:#{node['test']}").first

aws_ec2_volume node['test'] do
  action :attach
  instance_id ebs_test_node[:ec2][:instance_id]
  device '/dev/xvdf'
end

include_recipe 'aws_ebs_volume_fixture'

ebs_test_node = search(:node, "*:#{node['test']}").first

volume1 = aws_ebs_volume node['test'] do
  action [:create, :attach, :detach, :delete]
  availability_zone 'us-west-2a'
  size 10
  volume_type :io1
  iops 300
  instance_id ebs_test_node[:ec2][:instance_id]
  device '/dev/xvdf'
end

volume2 = aws_ebs_volume "#{node['test']}-2" do
  action [:create, :attach, :detach, :delete]
  availability_zone 'us-west-2a'
  size 10
  volume_type :io1
  iops 300
  instance_id ebs_test_node[:ec2][:instance_id]
  device '/dev/xvdg'
end

volume1.run_action(:create)
volume1.run_action(:create)

volume1.run_action(:attach)
volume1.run_action(:attach)

volume2.run_action(:create)
volume2.run_action(:create)

volume2.run_action(:attach)
volume2.run_action(:attach)

volume1.run_action(:detach)
volume1.run_action(:detach)

volume1.run_action(:delete)
volume1.run_action(:delete)

volume2.run_action(:detach)
volume2.run_action(:detach)

volume2.run_action(:delete)
volume2.run_action(:delete)

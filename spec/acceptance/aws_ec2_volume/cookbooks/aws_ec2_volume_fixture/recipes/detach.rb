include_recipe 'aws_ec2_volume_fixture'

aws_ec2_volume node['test'] do
  action :detach
end

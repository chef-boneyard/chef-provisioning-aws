include_recipe 'aws_ebs_volume_fixture'

aws_ebs_volume node['test'] do
  action :detach
end

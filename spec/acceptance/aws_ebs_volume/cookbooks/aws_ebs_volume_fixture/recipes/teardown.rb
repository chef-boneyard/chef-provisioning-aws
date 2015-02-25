include_recipe 'aws_ebs_volume_fixture'

machine node['test'] do
  action :destroy
end

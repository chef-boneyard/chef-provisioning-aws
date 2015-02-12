include_recipe 'aws_ec2_volume_fixture'

machine node['test'] do
  action :destroy
end

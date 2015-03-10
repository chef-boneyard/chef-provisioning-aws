require 'chef/provisioning/aws_driver'

with_driver 'aws::eu-west-1'

load_balancer 'ref-load-balancer' do
  action :destroy
end

machine_batch do
  action :destroy
  machines 'ref-machine1', 'ref-machine2'
end

machine_image 'ref-machine_image3' do
  action :destroy
end

machine_image 'ref-machine_image2' do
  action :destroy
end

machine_image 'ref-machine_image1' do
  action :destroy
end

aws_subnet 'ref-subnet' do
  action :delete
end

aws_security_group 'ref-sg2' do
  action :delete
end

aws_security_group 'ref-sg1' do
  action :delete
end

ruby_block 'destroy vpc children' do
  block do
    vpc = Chef::Resource::AwsVpc.get_aws_object('ref-vpc', run_context: run_context)
    ig = vpc.internet_gateway
    ig.detach(vpc)
    ig.delete
  end
  only_if do
    vpc = Chef::Resource::AwsVpc.get_aws_object('ref-vpc', run_context: run_context)
    vpc && vpc.internet_gateway
  end
end

aws_vpc 'ref-vpc' do
  action :delete
end

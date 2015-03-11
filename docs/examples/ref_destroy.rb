require 'chef/provisioning/aws_driver'

with_driver 'aws::eu-west-1'

aws_sqs_queue 'ref-sqs-queue' do
  action :delete
end

aws_sns_topic 'ref-sns-topic' do
  action :delete
end

aws_s3_bucket 'ref-s3-bucket' do
  action :delete
end

aws_eip_address 'ref-elastic-ip' do
  action :delete
end

aws_ebs_volume 'ref-volume' do
  action :delete
end

aws_auto_scaling_group 'ref-auto-scaling-group' do
  action :delete
end

aws_launch_configuration 'ref-launch-configuration' do
  action :delete
end

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

aws_route_table 'ref-public' do
  action :delete
end

aws_security_group 'ref-sg2' do
  action :delete
end

aws_security_group 'ref-sg1' do
  action :delete
end

aws_key_pair 'ref-key-pair' do
  action :delete
end

aws_vpc 'ref-vpc' do
  action :delete
end

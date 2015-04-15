require 'chef/provisioning/aws_driver'

with_driver 'aws::eu-west-1'

aws_dhcp_options 'ref-dhcp-options' do
end

aws_vpc 'ref-vpc' do
  cidr_block '10.0.0.0/24'
  internet_gateway true
  main_routes '0.0.0.0/0' => :internet_gateway
  dhcp_options 'ref-dhcp-options'
end

aws_key_pair 'ref-key-pair' do
end

aws_security_group 'ref-sg1' do
  vpc 'ref-vpc'
  inbound_rules '0.0.0.0/0' => 22
end

aws_security_group 'ref-sg2' do
  vpc 'ref-vpc'

  inbound_rules 'ref-sg1' => 2224
  outbound_rules 2224 => 'ref-sg1'
end

aws_route_table 'ref-public' do
  vpc 'ref-vpc'
  routes '0.0.0.0/0' => :internet_gateway
end

aws_subnet 'ref-subnet' do
  vpc 'ref-vpc'
  map_public_ip_on_launch true
  route_table 'ref-public'
end

machine_image 'ref-machine_image1' do
end

machine_image 'ref-machine_image2' do
  from_image 'ref-machine_image1'
end

machine_image 'ref-machine_image3' do
  machine_options bootstrap_options: { subnet_id: 'ref-subnet', security_group_ids: 'ref-sg1', image_id: 'ref-machine_image1' }
end

machine_batch do
  machine 'ref-machine1' do
    machine_options bootstrap_options: { image_id: 'ref-machine_image1' }
  end
  machine 'ref-machine2' do
    from_image 'ref-machine_image1'
    machine_options bootstrap_options: { key_name: 'ref-key-pair', subnet_id: 'ref-subnet', security_group_ids: 'ref-sg1' }
  end
end

load_balancer 'ref-load-balancer' do
  machines [ 'ref-machine2' ]
end

aws_launch_configuration 'ref-launch-configuration' do
  image 'ref-machine_image1'
  options security_groups: 'ref-sg1'
end

aws_auto_scaling_group 'ref-auto-scaling-group' do
  launch_configuration 'ref-launch-configuration'
  load_balancers 'ref-load-balancer'
  options subnets: 'ref-subnet'
end

aws_ebs_volume 'ref-volume' do
  availability_zone 'a'
  size 1
  machine 'ref-machine1'
  device '/dev/xvdf'
end

aws_eip_address 'ref-elastic-ip' do
  machine 'ref-machine1'
  action :associate
end

aws_s3_bucket 'ref-s3-bucket' do
end

aws_sqs_queue 'ref-sqs-queue' do
end

aws_sns_topic 'ref-sns-topic' do
end

require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-1'

#
# This recipe sets every single value of every single object
#

# aws_vpc 'ref-vpc' do
#   action :purge
# end

aws_dhcp_options 'ref-dhcp-options' do
  domain_name          'example.com'
  domain_name_servers  %w(8.8.8.8 8.8.4.4)
  ntp_servers          %w(8.8.8.8 8.8.4.4)
  netbios_name_servers %w(8.8.8.8 8.8.4.4)
  netbios_node_type    2
end

aws_vpc 'ref-vpc' do
  cidr_block '10.0.0.0/24'
  internet_gateway true
  instance_tenancy :default
  main_routes '0.0.0.0/0' => :internet_gateway
  dhcp_options 'ref-dhcp-options'
  enable_dns_support true
  enable_dns_hostnames true
end

aws_route_table 'ref-main-route-table' do
  vpc 'ref-vpc'
  routes '0.0.0.0/0' => :internet_gateway
end

aws_vpc 'ref-vpc' do
  main_route_table 'ref-main-route-table'
end

aws_key_pair 'ref-key-pair' do
  private_key_options({
    :format => :pem,
    :type => :rsa,
    :regenerate_if_different => true
  })
  allow_overwrite true
end

aws_security_group 'ref-sg1' do
  vpc 'ref-vpc'
  inbound_rules '0.0.0.0/0' => [ 22, 80 ]
  outbound_rules [
    {:port => 22..22, :protocol => :tcp, :destinations => ['0.0.0.0/0'] }
  ]
end

aws_route_table 'ref-public' do
  vpc 'ref-vpc'
  routes '0.0.0.0/0' => :internet_gateway
end

aws_subnet 'ref-subnet' do
  vpc 'ref-vpc'
  cidr_block '10.0.0.0/24'
  availability_zone 'us-west-1a'
  map_public_ip_on_launch true
  route_table 'ref-public'
end

machine_image 'ref-machine_image1' do
  image_options description: 'some image description'
end

machine_image 'ref-machine_image2' do
  from_image 'ref-machine_image1'
end

machine_image 'ref-machine_image3' do
  machine_options bootstrap_options: {
    # for some reason, sshing into this host takes 20+ seconds with these enabled
    #subnet_id: 'ref-subnet',
    #security_group_ids: 'ref-sg1',
    image_id: 'ref-machine_image1',
    instance_type: 't2.small'
  }
end

machine_batch do
  machine 'ref-machine1' do
    machine_options bootstrap_options: { image_id: 'ref-machine_image1', :availability_zone => 'us-west-1a', instance_type: 'm3.medium' }
    ohai_hints 'ec2' => { 'a' => 'b' }
    converge false
  end
  machine 'ref-machine2' do
    from_image 'ref-machine_image1'
    machine_options bootstrap_options: {
      key_name: 'ref-key-pair',
      #subnet_id: 'ref-subnet',
      #security_group_ids: 'ref-sg1'
    }
  end
end

load_balancer 'ref-load-balancer' do
  machines [ 'ref-machine2' ]
end

aws_launch_configuration 'ref-launch-configuration' do
  image 'ref-machine_image1'
  instance_type 't1.micro'
  options security_groups: 'ref-sg1'
end

aws_auto_scaling_group 'ref-auto-scaling-group' do
  availability_zones ['us-west-1a']
  desired_capacity 2
  min_size 1
  max_size 3
  launch_configuration 'ref-launch-configuration'
  load_balancers 'ref-load-balancer'
  options subnets: 'ref-subnet'
end

aws_ebs_volume 'ref-volume' do
  machine 'ref-machine1'
  availability_zone 'a'
  size 100
  #snapshot
  iops 3000
  volume_type 'io1'
  encrypted true
  device '/dev/sda2'
end

aws_eip_address 'ref-elastic-ip' do
  machine 'ref-machine1'
  associate_to_vpc true
end

aws_s3_bucket 'ref-s3-bucket' do
  enable_website_hosting true
  options({ :acl => 'private' })
end

aws_sqs_queue 'ref-sqs-queue' do
  options({ :delay_seconds => 1 })
end

aws_sns_topic 'ref-sns-topic' do
end

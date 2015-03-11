require 'chef/provisioning/aws_driver'

with_driver 'aws::eu-west-1'

vpc_resource = aws_vpc 'ref-vpc' do
  cidr_block '10.0.0.0/24'
  # internet_gateway true
  # main_routes '0.0.0.0/0' => :internet_gateway
end

# Remove these when aws_vpc.internet_gateway works
ruby_block 'attach internet gateway' do
  block do
    vpc = vpc_resource.aws_object
    if !vpc.internet_gateway
      driver = run_context.chef_provisioning.driver_for(run_context.chef_provisioning.current_driver)
      vpc.internet_gateway = driver.ec2.internet_gateways.create
    end
    vpc.route_tables.main_route_table.create_route('0.0.0.0/0', internet_gateway: vpc.internet_gateway)
  end
  only_if do
    !vpc_resource.aws_object.internet_gateway
  end
end

aws_key_pair 'ref-key-pair' do
end

aws_security_group 'ref-sg1' do
  vpc 'ref-vpc'
  inbound_rules [ { ports: 22, protocol: :tcp, sources: [ '0.0.0.0/0' ] } ]
end

aws_security_group 'ref-sg2' do
  vpc 'ref-vpc'

  inbound_rules [
    {:ports => 2223, :protocol => :tcp, :sources => ['ref-sg1'] }
  ]
  outbound_rules [
    {:ports => 2223, :protocol => :tcp, :destinations => ['ref-sg1'] }
  ]
end

aws_subnet 'ref-subnet' do
  vpc 'ref-vpc'
  map_public_ip_on_launch true
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
  availability_zone 'eu-west-1a'
  size 1
end

# attach above volume to machine somehow ...

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

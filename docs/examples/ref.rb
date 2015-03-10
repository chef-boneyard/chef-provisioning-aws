require 'chef/provisioning/aws_driver'

with_driver 'aws::eu-west-1'

aws_vpc 'ref-vpc' do
  cidr_block '10.0.0.0/24'
  # internet_gateway true
  # main_routes '0.0.0.0/0' => :internet_gateway
end


# Remove these when aws_vpc.internet_gateway works
ruby_block 'attach internet gateway' do
  block do
    vpc = Chef::Resource::AwsVpc.get_aws_object('ref-vpc', run_context: run_context)
    if vpc
      if !vpc.internet_gateway
        driver = run_context.chef_provisioning.driver_for(run_context.chef_provisioning.current_driver)
        vpc.internet_gateway = driver.ec2.internet_gateways.create
      end
      vpc.route_tables.main_route_table.create_route('0.0.0.0/0', internet_gateway: vpc.internet_gateway)
    end
  end
  only_if do
    vpc = Chef::Resource::AwsVpc.get_aws_object('ref-vpc', run_context: run_context)
    !vpc.internet_gateway
  end
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
    machine_options bootstrap_options: { subnet_id: 'ref-subnet', security_group_ids: 'ref-sg1' }
  end
end

load_balancer 'ref-load-balancer' do
  machines [ 'ref-machine2' ]
end

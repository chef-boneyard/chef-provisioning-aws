require 'chef/provisioning/aws_driver'

with_driver 'aws::eu-west-1'
  aws_vpc "provisioning-vpc" do
    cidr_block "10.0.0.0/24"
    internet_gateway true
    internet_gateway_routes '0.0.0.0/0'
  end

  aws_subnet "provisioning-vpc-subnet-a" do
    vpc "provisioning-vpc"
    cidr_block "10.0.0.0/26"
    availability_zone "eu-west-1a"
    map_public_ip_on_launch true
  end

  aws_subnet "provisioning-vpc-subnet-b" do
    vpc "provisioning-vpc"
    cidr_block "10.0.0.128/26"
    availability_zone "eu-west-1a"
    map_public_ip_on_launch true
  end

machine_batch do
  machines %w(mario-a mario-b)
  action :destroy
end

machine_batch do
  machine 'mario-a' do
    machine_options bootstrap_options: { subnet: 'provisioning-vpc-subnet-a' }
  end

  machine 'mario-b' do
    machine_options bootstrap_options: { subnet: 'provisioning-vpc-subnet-b' }
  end
end

aws_security_group "provisioning-vpc-security-group" do
  inbound_rules [
    {:ports => 2223, :protocol => :tcp, :sources => ["10.0.0.0/24"] },
    {:ports => 80..100, :protocol => :udp, :sources => ["1.1.1.0/24"] }
  ]
  outbound_rules [
    {:ports => 2223, :protocol => :tcp, :destinations => ["1.1.1.0/16"] },
    {:ports => 8080, :protocol => :tcp, :destinations => ["2.2.2.0/24"] }
  ]
  vpc_name "provisioning-vpc"
end

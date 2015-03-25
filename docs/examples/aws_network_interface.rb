require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

aws_key_pair 'ref-key-pair-eni'

with_machine_options :bootstrap_options => { :key_name => 'ref-key-pair-eni' }

#machine 'ref-machine-1'

aws_dhcp_options 'ref-dhcp-options-eni' do
end

aws_vpc 'ref-vpc-eni' do
  cidr_block '10.0.0.0/24'
  internet_gateway true
  main_routes '0.0.0.0/0' => :internet_gateway
  dhcp_options 'ref-dhcp-options-eni'
end

aws_security_group 'ref-sg1-eni' do
  vpc 'ref-vpc-eni'
  inbound_rules '0.0.0.0/0' => 22
end

aws_security_group 'ref-sg2-eni' do
  vpc 'ref-vpc-eni'
  inbound_rules 'ref-sg1-eni' => 2224
  outbound_rules 2224 => 'ref-sg1-eni'
end

aws_route_table 'ref-public-eni' do
  vpc 'ref-vpc-eni'
  routes '0.0.0.0/0' => :internet_gateway
end

aws_subnet 'ref-subnet-eni' do
  vpc 'ref-vpc-eni'
  map_public_ip_on_launch true
  route_table 'ref-public-eni'
end

aws_network_interface 'ref-eni-1' do
  subnet 'ref-subnet-eni'
  security_groups [ 'ref-sg1-eni', 'ref-sg2-eni' ]
end

require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

aws_key_pair 'ref-key-pair-eni'

#common_machine_options = { :bootstrap_options => { :key_name => 'ref-key-pair-eni'}

aws_dhcp_options 'ref-dhcp-options-eni' do
end

aws_vpc 'ref-vpc-eni' do
  cidr_block '10.0.0.0/24'
  internet_gateway true
  main_routes '0.0.0.0/0' => :internet_gateway
  dhcp_options 'ref-dhcp-options-eni'
end

sg1 = aws_security_group 'ref-sg1-eni' do
  vpc 'ref-vpc-eni'
  inbound_rules '0.0.0.0/0' => 22
end

sg2 = aws_security_group 'ref-sg2-eni' do
  vpc 'ref-vpc-eni'
  inbound_rules 'ref-sg1-eni' => 2224
  outbound_rules 2224 => 'ref-sg1-eni'
end

aws_route_table 'ref-public-eni' do
  vpc 'ref-vpc-eni'
  routes '0.0.0.0/0' => :internet_gateway
end

subnet = aws_subnet 'ref-subnet-eni' do
  vpc 'ref-vpc-eni'
  map_public_ip_on_launch true
  route_table 'ref-public-eni'
end

# machine 'ref-machine-eni-1' do
#   machine_options :bootstrap_options => { 
#     :subnet_id => lazy {subnet.aws_object.id},
#     :key_name => 'ref-key-pair-eni',
# #    :security_group_ids => lazy { [sg1.aws_object.id, sg2.aws_object.id] }
#   }
# end

aws_network_interface 'ref-eni-1' do
  subnet 'ref-subnet-eni'
  security_groups lazy { [sg1.aws_object.id, sg2.aws_object.id] } # TODO not working
end

# aws_network_interface 'ref-eni-1' do
#   machine 'ref-machine-eni-1'
# end

# aws_network_interface 'ref-eni-1' do
#   machine false
# end

aws_network_interface 'ref-eni-1' do
  action :destroy
end

machine 'ref-machine-eni-1' do
  action :destroy
end

aws_subnet 'ref-subnet-eni' do
  action :destroy
end

aws_route_table 'ref-public-eni' do
  action :destroy
end

aws_security_group 'ref-sg2-eni' do
  action :destroy
end

aws_security_group 'ref-sg1-eni' do
  action :destroy
end

aws_vpc 'ref-vpc-eni' do
  action :destroy
end

aws_dhcp_options 'ref-dhcp-options-eni' do
  action :destroy
end

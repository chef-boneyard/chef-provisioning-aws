## Recipe to create a nat gateway in public subnet and associate it to private route table in private subnet
require "chef/provisioning/aws_driver"

with_driver "aws::eu-west-1"

aws_vpc "test-vpc" do
  cidr_block "10.0.0.0/16"
  internet_gateway true
end

aws_route_table "public_route" do
  vpc "test-vpc"
  routes "0.0.0.0/0" => :internet_gateway
end


aws_subnet "public_subnet" do
  vpc "test-vpc"
  cidr_block "10.0.1.0/24"
  availability_zone "eu-west-1a"
  map_public_ip_on_launch false
  route_table "public_route"
end


aws_eip_address 'nat-elastic-ip'

nat = aws_nat_gateway 'nat-gateway' do
  subnet "public_subnet"
  eip_address "nat-elastic-ip"
end

aws_route_table "private_route" do
  routes '0.0.0.0/0' =>  nat.aws_object.id
  vpc "test-vpc"
end

aws_subnet "private_subnet" do
  vpc "test-vpc"
  cidr_block "10.0.3.0/24"
  availability_zone "eu-west-1a"
  map_public_ip_on_launch false
  route_table "private_route"
end

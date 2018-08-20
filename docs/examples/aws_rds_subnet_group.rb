aws_vpc "coolvpc" do
  cidr_block "10.0.0.0/24"
  internet_gateway true
end

subnet1 = aws_subnet "subnet" do
  vpc "coolvpc"
  cidr_block "10.0.0.0/26"
  availability_zone "us-east-1a"
end

subnet2 = aws_subnet "subnet_2" do
  vpc "coolvpc"
  cidr_block "10.0.0.64/26"
  availability_zone "us-east-1c"
end

# Note that rds subnet groups need two subnets in different
# availability zones to function, that is why two subnets are defined
# in this example.
aws_rds_subnet_group "db-subnet-group" do
  description "some_description"
  subnets ["subnet", subnet2.aws_object.id]
end

aws_rds_instance "rds-instance" do
  engine "postgres"
  publicly_accessible false
  db_instance_class "db.t1.micro"
  master_username "thechief"
  master_user_password "securesecure" # 2x security
  multi_az false
  db_subnet_group_name "db-subnet-group"
end

require 'chef/provisioning/aws_driver'
with_driver 'aws'

with_data_center 'eu-west-1' do
  aws_vpc "provisioning-vpc" do 
    cidr_block "10.0.0.0/16"
  end

  aws_subnet "provisioning-vpc-subnet-a" do
    cidr_block "10.0.1.0/24"
    vpc "provisioning-vpc"
    availability_zone "eu-west-1a"
  end

  aws_subnet "provisioning-vpc-subnet-b" do
    cidr_block "10.0.2.0/24"
    vpc "provisioning-vpc"
    availability_zone "eu-west-1a"
  end

  aws_security_group "provisioning-vpc-security-group" do 
    inbound_rules [ 
      {:ports => 1433, :protocol => :tcp, :sources => ["0.0.0.0/0"] },
    ]
    vpc_name "provisioning-vpc"
  end

  aws_rds_db_instance "provisioning-vpc-rds-db-instance" do
    engine 'MySql'
    db_instance_class 'db.t2.small'
    allocated_storage 100
    master_username 'Administrator'
    master_user_password 'G3t0ut0fMyK1tchen!'
  end
end

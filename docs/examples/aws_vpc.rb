require 'chef/provisioning/aws_driver'
with_driver 'aws'

with_data_center 'eu-west-1' do
  aws_vpc "provisioning-vpc" do 
    cidr_block "10.0.1.0/24"
  end

  subnet "provisioning-vpc-subnet-a" do
    cidr_block "10.0.1.0/26"
    vpc "provisioning-vpc"
    availability_zone "eu-west-1a"
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
end

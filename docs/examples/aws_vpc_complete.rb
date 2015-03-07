# Best Practices
# --------------
# VPC
# Self-Healing Provisioning
# Logging and Monitoring
# Chaos Monkey

# security groups
# bastion instance

# This is an *aspirational* recipe.  It does not exist yet.

# - aws_vpc: dns_resolution, dns_hostnames, domain_name, domain_name_servers
# - aws_route53_hosted_zone
# - aws_route53_recordset
# - aws_route_table
# - maybe better syntax on security groups?
# - machine bootstrap_options: security_group by name, route53_hosted_zone by name
# - aws_subnet: route_table
# - with_aws_vpc
require 'chef/provisioning/aws_driver'

%w(us-east-1 us-west-1).each do |region|
  with_driver "aws::#{region}" do
    aws_basic_vpc "my_vpc-#{region}" do
      domain_name 'blah.com.internal.'
    end
  end
end

with_driver 'aws::us-east-1' do
  #
  # Create DNS mirror servers
  #

  #
  # Create VPC
  #
  aws_vpc "top" do
    cidr_block "10.0.0.0/16" # big block
    dns_resolution true   # This tells the DHCP server to tell clients about the
                          # amazon DNS server.  We will override that later
                          # because the amazon DNS server has bad names.
    dns_hostnames true    # This turns on internal hostnames in the Amazon DNS
                          # server, so that instances can talk to each other using
                          # hostnames.
    internet_gateway true # This creates a gateway to the internet.  Without it,
                          # no internet for you.

    # DHCP options
    domain_name 'blah.com' # Internal domain name, all new instances will have a
                           # name under this.
#    domain_name_servers ''
#    ntp_servers
#    netbios_name_servers
#    netbios_node_type

    # default_tenancy 'dedicated_hosting' # nobody ever does this, it costs money.
  end

  aws_route53_hosted_zone 'top-zone' do
    type :private
    vpc 'top'
    domain_name 'blahdeblah.com.internal.'
    comment 'asdflkjasdfdsa'
  end

  aws_security_group 'bastion-can-ssh-to-me' do
    allow_port 'bastion' => 22
  end

  with_machine_options bootstrap_options: {
    security_group: 'bastion-can-ssh-to-me'
  }

  # If you were doing geodistributed DNS or something
  # aws_dhcp_options 'my_options' do
  #   domain_name 'blah.com'
  #   domain_name_servers
  #   ntp_servers
  #   netbios_name_servers
  #   netbiod_node_type
  # end

  availability_zones = %w(us-east-1a us-east-1b us-east-1c)

  with_aws_vpc 'top' do

    #
    # Build public subnets and NATs
    #

    aws_route_table 'public-routes' do
      local_route '10.0.0.0/16'
    end

    availability_zones.each do |availability_zone|
      class_c = (availability_zone[-1..-1].ord - 'a'.ord)

      # Remove the default subnet
      aws_subnet "default" do
        availability_zone availability_zone
        action :destroy
      end

      # Add a public subnet
      aws_subnet "public-#{availability_zone}" do
        availability_zone availability_zone
        cidr_block "10.0.#{128+class_c}.0/24"
        route_table 'public-routes'
        map_public_ip_on_launch true
      end

      # Default single NAT

      # aws ec2 describe-images --filter Name="owner-alias",Values="amazon"
      #                         --filter Name="name",Values="amzn-ami-vpc-nat*"

      machine "nat-#{availability_zone}" do
        add_machine_options bootstrap_options: {
          subnet: "public-#{availability_zone}",
          image_id: { 'owner-alias' => 'amazon', 'name' => 'amzn-ami-vpc-nat' },
          route53_private_hosted_zone: 'private-zone' # other options may be needed, TTL, etc.
        }
        # If we had complicated DNS, we'd have to do a custom recipe that tells the server its DNS
      end

      # lynchc: custom NAT with keepalive and pairs
      # 0.upto(1).each do |i|
      #   machine "nat-#{i}-#{availability_zone}" do
      #     machine_options bootstrap_options: {
      #       subnet: "public-#{availability_zone}",
      #       image_id: ...
      #     }
      #     recipe 'lynchcs-awesome-nat-recipe'
      #   end
      # end
    end

    # Complicated DNS goes here: see below

    #
    # Build private subnets
    #
    aws_route_table 'private-routes' do
      routes '10.0.0.0/16' => :internet_gateway,
             '0.0.0.0/0' => "nat-#{availability_zone}"
    end

    %w(us-east-1a us-east-1b us-east-1c).each do |availability_zone|
      aws_subnet "private-#{availability_zone}" do
        availability_zone availability_zone
        cidr_block "10.0.#{class_c}.0/24"
        route_table 'private-routes'
      end
    end
  end
end

#
#
# Complicated DNS
#
#

#
# Build the internal DNS mirrors
#
machine_batch do
  # First create them and get their IPs
  availability_zones.each do |availability_zone|
    machine "dns-mirror-#{availability_zone}" do
      add_machine_options bootstrap_options: {
        subnet: "public-#{availability_zone}",
        image_id: { 'owner-alias' => 'amazon', 'name' => 'amzn-ami-vpc-nat' }
        security_group: 'availability-zone'
      }
      tag 'dns-mirror'
      tag 'ntp-server'
    end
  end
end
machine_batch do
  availability_zones.each do |availability_zone|
    machine "dns-mirror-#{availability_zone}" do
      # have awesome-dns recipes search for tag:dns-mirror to set up dns mirrors
      recipe 'awesome-dns'
      recipe 'awesome-ntp'
    end
  end
end

# DHCP options
aws_vpc 'top' do
  domain_name_servers lazy { search('tag:dns-mirror').map { |n| n.normal['ip_address'] } }
  ntp_servers lazy { search('tag:ntp-server').map { |n| n.normal['ip_address'] } }
end


# This SG allows SSH access to the bastion server, and nothing else
aws_security_group "bastion" do

end

machine 'bastion' do
  add_machine_options bootstrap_options: {
    subnet: "public-#{availability_zones.first}",
    image_id: { },
    security_group: 'bastion'
  }
  recipe 'ssh-server'
end

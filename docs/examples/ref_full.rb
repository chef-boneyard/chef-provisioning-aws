require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-1'

#
# This recipe sets every single value of every single object
#

# aws_vpc 'ref-vpc' do
#   action :purge
# end

aws_dhcp_options 'ref-dhcp-options' do
  domain_name          'example.com'
  domain_name_servers  %w(8.8.8.8 8.8.4.4)
  ntp_servers          %w(8.8.8.8 8.8.4.4)
  netbios_name_servers %w(8.8.8.8 8.8.4.4)
  netbios_node_type    2
  aws_tags :chef_type => "aws_dhcp_options"
end

aws_vpc 'ref-vpc' do
  cidr_block '10.0.0.0/24'
  internet_gateway true
  instance_tenancy :default
  main_routes '0.0.0.0/0' => :internet_gateway
  dhcp_options 'ref-dhcp-options'
  enable_dns_support true
  enable_dns_hostnames true
  aws_tags :chef_type => "aws_vpc"
end

aws_route_table 'ref-main-route-table' do
  vpc 'ref-vpc'
  routes '0.0.0.0/0' => :internet_gateway
  aws_tags :chef_type => "aws_route_table"
end

aws_vpc 'ref-vpc' do
  main_route_table 'ref-main-route-table'
end

aws_key_pair 'ref-key-pair' do
  private_key_options({
    :format => :pem,
    :type => :rsa,
    :regenerate_if_different => true
  })
  allow_overwrite true
end

aws_security_group 'ref-sg1' do
  vpc 'ref-vpc'
  inbound_rules '0.0.0.0/0' => [ 22, 80 ]
  outbound_rules [
    {:port => 22..22, :protocol => :tcp, :destinations => ['0.0.0.0/0'] }
  ]
  aws_tags :chef_type => "aws_security_group"
end

aws_route_table 'ref-public' do
  vpc 'ref-vpc'
  routes '0.0.0.0/0' => :internet_gateway
  aws_tags :chef_type => "aws_route_table"
end

aws_network_acl 'ref-acl' do
  vpc 'ref-vpc'
  inbound_rules(
    [
      { rule_number: 100, action: :allow, protocol: -1, cidr_block: '0.0.0.0/0' },
      { rule_number: 200, action: :allow, protocol: 6, port_range: 443..443, cidr_block: '172.31.0.0/24' }
    ]
  )
  outbound_rules(
    [
      { rule_number: 100, action: :allow, protocol: -1, cidr_block: '0.0.0.0/0' }
    ]
  )
end

aws_subnet 'ref-subnet' do
  vpc 'ref-vpc'
  cidr_block '10.0.0.0/26'
  availability_zone 'us-west-1a'
  map_public_ip_on_launch true
  route_table 'ref-public'
  aws_tags :chef_type => "aws_subnet"
  network_acl 'ref-acl'
end

ref_subnet_2 = aws_subnet 'ref-subnet-2' do
  vpc 'ref-vpc'
  cidr_block '10.0.0.64/26'
  availability_zone 'us-west-1b'
  map_public_ip_on_launch true
  route_table 'ref-public'
  aws_tags :chef_type => "aws_subnet"
  network_acl 'ref-acl'
end

aws_rds_subnet_group "ref-db-subnet-group" do
  description "some_description"
  subnets ['ref-subnet', lazy { ref_subnet_2.aws_object.id} ]
end

aws_rds_instance "ref-rds-instance" do
  engine "postgres"
  publicly_accessible false
  db_instance_class "db.t1.micro"
  master_username "thechief"
  master_user_password "securesecure" # 2x security
  multi_az false
  db_subnet_group_name "ref-db-subnet-group"
  allocated_storage 5
end

# We cover tagging the base chef-provisioning resources in aws_tags.rb
machine_image 'ref-machine_image1' do
  image_options description: 'some image description'
end

machine_image 'ref-machine_image2' do
  from_image 'ref-machine_image1'
end

machine_image 'ref-machine_image3' do
  machine_options bootstrap_options: {
    # for some reason, sshing into this host takes 20+ seconds with these enabled
    #subnet_id: 'ref-subnet',
    #security_group_ids: 'ref-sg1',
    image_id: 'ref-machine_image1',
    instance_type: 't2.small'
  }
end

machine_batch do
  machine 'ref-machine1' do
    machine_options bootstrap_options: { image_id: 'ref-machine_image1', :availability_zone => 'us-west-1a', instance_type: 'm3.medium' }
    ohai_hints 'ec2' => { 'a' => 'b' }
    converge false
  end
  machine 'ref-machine2' do
    from_image 'ref-machine_image1'
    machine_options bootstrap_options: {
      key_name: 'ref-key-pair',
      #subnet_id: 'ref-subnet',
      #security_group_ids: 'ref-sg1'
    }
  end
end

load_balancer 'ref-load-balancer' do
  machines [ 'ref-machine2' ]
  load_balancer_options(
    attributes: {
      cross_zone_load_balancing: {
        enabled: true
      }
    }
  )
end

aws_launch_configuration 'ref-launch-configuration' do
  image 'ref-machine_image1'
  instance_type 't1.micro'
  options security_groups: 'ref-sg1'
end

aws_auto_scaling_group 'ref-auto-scaling-group' do
  availability_zones ['us-west-1a']
  desired_capacity 2
  min_size 1
  max_size 3
  launch_configuration 'ref-launch-configuration'
  load_balancers 'ref-load-balancer'
  options subnets: 'ref-subnet'
end

aws_ebs_volume 'ref-volume' do
  machine 'ref-machine1'
  availability_zone 'a'
  size 100
  #snapshot
  iops 3000
  volume_type 'io1'
  encrypted true
  device '/dev/sda2'
  aws_tags :chef_type => "aws_ebs_volume"
end

aws_eip_address 'ref-elastic-ip' do
  machine 'ref-machine1'
  associate_to_vpc true
  # guh - every other AWSResourceWithEntry accepts tags EXCEPT this one
end

aws_s3_bucket 'ref-s3-bucket' do
  enable_website_hosting true
  options({ :acl => 'private' })
end

aws_sqs_queue 'ref-sqs-queue' do
  options({ :delay_seconds => 1 })
end

aws_sns_topic 'ref-sns-topic' do
end

aws_server_certificate "ref-server-certificate" do
  certificate_body "-----BEGIN CERTIFICATE-----\nMIIE+TCCA+GgAwIBAgIQU306HIX4KsioTW1s2A2krTANBgkqhkiG9w0BAQUFADCB\ntTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL\nExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTswOQYDVQQLEzJUZXJtcyBvZiB1c2Ug\nYXQgaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYSoAYykwOTEvMC0GA1UEAxMm\nVmVyaVNpZ24gQ2xhc3MgMyBTZWN1cmUgU2VydmVyIENBIC0gRzIwHhcNMTAxMDA4\nMDAwMDAwWhcNMTMxMDA3MjM1OTU5WjBqMQswCQYDVQQGEwJVUzETMBEGA1UECBMK\nV2FzaGluZ3RvbjEQMA4GA1UEBxQHU2VhdHRsZTEYMBYGA1UEChQPQW1hem9uLmNv\nbSBJbmMuMRowGAYDVQQDFBFpYW0uYW1hem9uYXdzLmNvbTCBnzANBgkqhkiG9w0B\nAQEFAAOBjQAwgYkCgYEA3Xb0EGea2dB8QGEUwLcEpwvGawEkUdLZmGL1rQJZdeeN\n3vaF+ZTm8Qw5Adk2Gr/RwYXtpx04xvQXmNm+9YmksHmCZdruCrW1eN/P9wBfqMMZ\nX964CjVov3NrF5AuxU8jgtw0yu//C3hWnOuIVGdg76626ggOoJSaj48R2n0MnVcC\nAwEAAaOCAdEwggHNMAkGA1UdEwQCMAAwCwYDVR0PBAQDAgWgMEUGA1UdHwQ+MDww\nOqA4oDaGNGh0dHA6Ly9TVlJTZWN1cmUtRzItY3JsLnZlcmlzaWduLmNvbS9TVlJT\nZWN1cmVHMi5jcmwwRAYDVR0gBD0wOzA5BgtghkgBhvhFAQcXAzAqMCgGCCsGAQUF\nBwIBFhxodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhMB0GA1UdJQQWMBQGCCsG\nAQUFBwMBBggrBgEFBQcDAjAfBgNVHSMEGDAWgBSl7wsRzsBBA6NKZZBIshzgVy19\nRzB2BggrBgEFBQcBAQRqMGgwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLnZlcmlz\naWduLmNvbTBABggrBgEFBQcwAoY0aHR0cDovL1NWUlNlY3VyZS1HMi1haWEudmVy\naXNpZ24uY29tL1NWUlNlY3VyZUcyLmNlcjBuBggrBgEFBQcBDARiMGChXqBcMFow\nWDBWFglpbWFnZS9naWYwITAfMAcGBSsOAwIaBBRLa7kolgYMu9BSOJsprEsHiyEF\nGDAmFiRodHRwOi8vbG9nby52ZXJpc2lnbi5jb20vdnNsb2dvMS5naWYwDQYJKoZI\nhvcNAQEFBQADggEBALpFBXeG782QsTtGwEE9zBcVCuKjrsl3dWK1dFiq3OP4y/Bi\nZBYEywBt8zNuYFUE25Ub/zmvmpe7p0G76tmQ8bRp/4qkJoiSesHJvFgJ1mksr3IQ\n3gaE1aN2BSUIHxGLn9N4F09hYwwbeEZaCxfgBiLdEIodNwzcvGJ+2LlDWGJOGrNI\nNM856xjqhJCPxYzk9buuCl1B4Kzu0CTbexz/iEgYV+DiuTxcfA4uhwMDSe0nynbn\n1qiwRk450mCOnqH4ly4P4lXo02t4A/DI1I8ZNct/Qfl69a2Lf6vc9rF7BELT0e5Y\n123RVWYBAZW00EXAMPLE456RVWYBAZW00EXAMPLE\n-----END CERTIFICATE-----\n"
  private_key "-----BEGIN RSA PRIVATE KEY-----\nMIICiTCCAfICCQD6m7oRw0uXOjANBgkqhkiG9w0BAQUFADCBiDELMAkGA1UEBhMC\nVVMxCzAJBgNVBAgTAldBMRAwDgYDVQQHEwdTZWF0dGxlMQ8wDQYDVQQKEwZBbWF6\nb24xFDASBgNVBAsTC0lBTSBDb25zb2xlMRIwEAYDVQQDEwlUZXN0Q2lsYWMxHzAd\nBgkqhkiG9w0BCQEWEG5vb25lQGFtYXpvbi5jb20wHhcNMTEwNDI1MjA0NTIxWhcN\nMTIwNDI0MjA0NTIxWjCBiDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAldBMRAwDgYD\nVQQHEwdTZWF0dGxlMQ8wDQYDVQQKEwZBbWF6b24xFDASBgNVBAsTC0lBTSBDb25z\nb2xlMRIwEAYDVQQDEwlUZXN0Q2lsYWMxHzAdBgkqhkiG9w0BCQEWEG5vb25lQGFt\nYXpvbi5jb20wgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAMaK0dn+a4GmWIWJ\n21uUSfwfEvySWtC2XADZ4nB+BLYgVIk60CpiwsZ3G93vUEIO3IyNoH/f0wYK8m9T\nrDHudUZg3qX4waLG5M43q7Wgc/MbQITxOUSQv7c7ugFFDzQGBzZswY6786m86gpE\nIbb3OhjZnzcvQAaRHhdlQWIMm2nrAgMBAAEwDQYJKoZIhvcNAQEFBQADgYEAtCu4\nnUhVVxYUntneD9+h8Mg9q6q+auNKyExzyLwaxlAoo7TJHidbtS4J5iNmZgXL0Fkb\nFFBjvSfpJIlJ00zbhNYS5f6GuoEDmFJl0ZxBHjJnyp378OD8uTs7fLvjx79LjSTb\nNYiytVbZPQUQ5Yaxu2jXnimvw3rrszlaEXAMPLE=\n-----END RSA PRIVATE KEY-----\n"
end

aws_cloudsearch_domain "ref-cs-domain" do
  multi_az false
  instance_type "search.m1.small"
  partition_count 2
  replication_count 2
  index_fields [{:index_field_name => "foo",
                 :index_field_type => "text"}]
end

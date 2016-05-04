require 'spec_helper'
require 'chef/resource/aws_security_group'
require 'chef/provisioning/aws_driver/exceptions'

describe Chef::Resource::AwsSecurityGroup do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "without a VPC" do

      it "aws_security_group 'test_sg' with no attributes works" do
        expect_recipe {
          aws_security_group 'test_sg' do
          end
        }.to create_an_aws_security_group('test_sg',
          description:                'test_sg',
          vpc_id:                     default_vpc.id,
          ip_permissions_list:        [],
          ip_permissions_list_egress: [{:groups=>[], :ip_ranges=>[{:cidr_ip=>"0.0.0.0/0"}], :ip_protocol=>"-1"}]
        ).and be_idempotent
      end

      it "can reference a security group by name or id" do
        expect_recipe {
          sg = aws_security_group 'test_sg'
          sg.run_action(:create)
          id = sg.aws_object.id
          aws_security_group id do
            inbound_rules '0.0.0.0/0' => 22
          end
          aws_security_group 'test_sg' do
            security_group_id id
            outbound_rules 22 => '0.0.0.0/0'
          end
        }.to create_an_aws_security_group('test_sg',
          description:                'test_sg',
          vpc_id:                     default_vpc.id,
          ip_permissions_list: [
            { groups: [], ip_ranges: [{cidr_ip: "0.0.0.0/0"}],  ip_protocol: "tcp", from_port: 22, to_port: 22},
          ],
          ip_permissions_list_egress: [
            {groups: [], ip_ranges: [{cidr_ip: "0.0.0.0/0"}], ip_protocol: "tcp", from_port: 22, to_port: 22 }
          ]

        ).and be_idempotent
      end

      it "raises an error trying to reference a security group by an unknown id" do
        expect_converge {
          aws_security_group 'sg-12345678'
        }.to raise_error(RuntimeError, /Chef::Resource::AwsSecurityGroup\[sg-12345678\] does not exist!/)
        expect_converge {
          aws_security_group 'test_sg' do
            security_group_id 'sg-12345678'
          end
        }.to raise_error(RuntimeError, /Chef::Resource::AwsSecurityGroup\[sg-12345678\] does not exist!/)
      end

      it "creates aws_security_group tags" do
        expect_recipe {
          aws_security_group 'test_sg' do
            aws_tags key1: "value"
          end
        }.to create_an_aws_security_group('test_sg')
        .and have_aws_security_group_tags('test_sg',
          {
            'Name' => 'test_sg',
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        aws_security_group 'test_sg' do
          aws_tags key1: "value"
        end

        it "updates aws_security_group tags" do
          expect_recipe {
            aws_security_group 'test_sg' do
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_security_group_tags('test_sg',
            {
              'Name' => 'test_sg',
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_security_group tags except Name" do
          expect_recipe {
            aws_security_group 'test_sg' do
              aws_tags({})
            end
          }.to have_aws_security_group_tags('test_sg',
            {
              'Name' => 'test_sg'
            }
          ).and be_idempotent
        end
      end

    end

    with_aws "in a VPC" do
      purge_all
      setup_public_vpc

      load_balancer "testloadbalancer" do
        load_balancer_options({
          subnets: ["test_public_subnet"],
          security_groups: ["test_security_group"]
        })
      end

      it "aws_security_group 'test_sg' with no attributes works" do
        expect_recipe {
          aws_security_group 'test_sg' do
            vpc 'test_vpc'
          end
        }.to create_an_aws_security_group('test_sg',
          vpc_id:                     test_vpc.aws_object.id,
          ip_permissions_list:        [],
          ip_permissions_list_egress: [{:groups=>[], :ip_ranges=>[{:cidr_ip=>"0.0.0.0/0"}], :ip_protocol=>"-1"}]
        ).and be_idempotent
      end

      it "can specify rules as a mapping from source/destination to port and protocol" do
        expect_recipe {
          aws_security_group 'test_sg' do
            # We need to define a list of ports and its easier to use a method than
            # have to add a new number when changing this test
            def counter()
              @ip_counter ||= 0
              @ip_counter += 1
            end

            vpc 'test_vpc'
            inbound_rules(
              "10.0.0.#{counter}/32" => { port_range: -1..-1, protocol: -1 },
              "10.0.0.#{counter}/32" => { port: -1, protocol: -1 },
              "10.0.0.#{counter}/32" => { port: 1002, protocol: -1 },
              "10.0.0.#{counter}/32" => { ports: 1003..1003, protocol: -1 },
              "10.0.0.#{counter}/32" => { port_range: 1004..1005, protocol: -1 },
              "10.0.0.#{counter}/32" => { port_range: [1006, 1007, 1108], protocol: -1 },
              # If the protocol isn't `-1` and you don't specify all the ports
              # aws wants `port_range` to be nil
              "10.0.0.#{counter}/32" => { ports: nil, protocol: :tcp },
              "10.0.0.#{counter}/32" => { port_range: 0..65535, protocol: :udp },
              "10.0.0.#{counter}/32" => { port_range: -1, protocol: :icmp },
              "10.0.0.#{counter}/32" => { port_range: 1..2, protocol: :icmp },
              "10.0.0.#{counter}/32" => { port_range: 1011, protocol: :any },
              "10.0.0.#{counter}/32" => { port_range: 1012, protocol: nil },
              "10.0.0.#{counter}/32" => { port: 1013 },
              "10.0.0.#{counter}/32" => { port: 1014..1014 },
              "10.0.0.#{counter}/32" => { port: [1015, 1016, 1117] },
              "10.0.0.#{counter}/32" => { port: :icmp },
              "10.0.0.#{counter}/32" => { port: 'tCp' },
              "10.0.0.#{counter}/32" => { port: nil },
              "10.0.0.#{counter}/32" => { protocol: -1 },
              "10.0.0.#{counter}/32" => { protocol: :any },
              "10.0.0.#{counter}/32" => { protocol: 'UDP' },
              "10.0.0.#{counter}/32" => { protocol: nil },
              "10.0.0.#{counter}/32" => 1020,
              "10.0.0.#{counter}/32" => 1021..1023,
              "10.0.0.#{counter}/32" => [1024, 1025, 1125],
              "10.0.0.#{counter}/32" => :icmp,
              "10.0.0.#{counter}/32" => 'Icmp',
              "10.0.0.#{counter}/32" => :tcp,
              "10.0.0.#{counter}/32" => 'UDP',
              "10.0.0.#{counter}/32" => nil,
              "10.0.0.#{counter}/32" => -1,
              "10.0.0.#{counter}/32" => :"-1",
              ["10.0.0.#{counter}/32", "10.0.0.#{counter}/32"] => :all,
              'test_security_group' => 1200,
              test_security_group.aws_object.id => 1201,
              test_security_group.aws_object => 1202,
              test_security_group => 1203,
              # cannot get the ID from the v1 api object
              #testloadbalancer.aws_object.id => 1205,
              testloadbalancer.aws_object => 1206,
              # Cannot specify a LoadBalancer resource, only AwsLoadBalancer
              #testloadbalancer => 1207,
              {group_name: 'test_security_group'} => 1208,
              {load_balancer: 'testloadbalancer'} => 1209,
              {security_group: 'test_security_group'} => 1210,
            )
            outbound_rules(
              { port_range: -1..-1, protocol: -1 } => "10.0.0.#{counter}/32",
              { port: -1, protocol: -1 } => "10.0.0.#{counter}/32",
              { port: 1002, protocol: -1 } => "10.0.0.#{counter}/32",
              { ports: 1003..1003, protocol: -1 } => "10.0.0.#{counter}/32",
              { port_range: 1004..1005, protocol: -1 } => "10.0.0.#{counter}/32",
              { port_range: [1006, 1007, 1108], protocol: -1 } => "10.0.0.#{counter}/32",
              # If the protocol isn't `-1` and you don't specify all the ports
              # aws wants `port_range` to be nil{ ports: nil, protocol: :tcp } => "10.0.0.#{counter}/32",
              { port_range: 0..65535, protocol: :udp } => "10.0.0.#{counter}/32",
              { port_range: -1, protocol: :icmp } => "10.0.0.#{counter}/32",
              { port_range: 1..2, protocol: :icmp } => "10.0.0.#{counter}/32",
              { port_range: 1011, protocol: :any } => "10.0.0.#{counter}/32",
              { port_range: 1012, protocol: nil } => "10.0.0.#{counter}/32",
              { port: 1013 } => "10.0.0.#{counter}/32",
              { port: 1014..1014 } => "10.0.0.#{counter}/32",
              { port: [1015, 1016, 1117] } => "10.0.0.#{counter}/32",
              { port: :icmp } => "10.0.0.#{counter}/32",
              { port: 'tCp' } => "10.0.0.#{counter}/32",
              { port: nil } => "10.0.0.#{counter}/32",
              { protocol: -1 } => "10.0.0.#{counter}/32",
              { protocol: :any } => "10.0.0.#{counter}/32",
              { protocol: 'UDP' } => "10.0.0.#{counter}/32",
              { protocol: nil } => "10.0.0.#{counter}/32",
              1020 => "10.0.0.#{counter}/32",
              1021..1023 => "10.0.0.#{counter}/32",
              [1024, 1025, 1125] => "10.0.0.#{counter}/32",
              :icmp => "10.0.0.#{counter}/32",
              'Icmp' => "10.0.0.#{counter}/32",
              :tcp => "10.0.0.#{counter}/32",
              'UDP' => "10.0.0.#{counter}/32",
              nil => "10.0.0.#{counter}/32",
              -1 => "10.0.0.#{counter}/32",
              :"-1" => "10.0.0.#{counter}/32",
              :all => ["10.0.0.#{counter}/32", "10.0.0.#{counter}/32"],
              1200 => 'test_security_group',
              1201 => test_security_group.aws_object.id,
              1202 => test_security_group.aws_object,
              1203 => test_security_group,
              # cannot get the ID from the v1 api object
              #1205 => testloadbalancer.aws_object.id,
              1206 => testloadbalancer.aws_object,
              # Cannot specify a LoadBalancer resource, only AwsLoadBalancer
              #1207 => testloadbalancer,
              1208 => {group_name: 'test_security_group'},
              1209 => {load_balancer: 'testloadbalancer'},
              1210 => {security_group: 'test_security_group'},
            )
          end
        }.to create_an_aws_security_group('test_sg',
          vpc_id: test_vpc.aws_object.id,
          ip_permissions_list: Set[
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.1/32"}, {:cidr_ip=>"10.0.0.11/32"}, {:cidr_ip=>"10.0.0.19/32"}, {:cidr_ip=>"10.0.0.2/32"}, {:cidr_ip=>"10.0.0.20/32"}, {:cidr_ip=>"10.0.0.3/32"}, {:cidr_ip=>"10.0.0.30/32"}, {:cidr_ip=>"10.0.0.32/32"}, {:cidr_ip=>"10.0.0.33/32"}, {:cidr_ip=>"10.0.0.34/32"}, {:cidr_ip=>"10.0.0.4/32"}, {:cidr_ip=>"10.0.0.5/32"}, {:cidr_ip=>"10.0.0.6/32"}], :ip_protocol=>"-1"},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.17/32"}, {:cidr_ip=>"10.0.0.18/32"}, {:cidr_ip=>"10.0.0.22/32"}, {:cidr_ip=>"10.0.0.28/32"}, {:cidr_ip=>"10.0.0.31/32"}, {:cidr_ip=>"10.0.0.7/32"}], :ip_protocol=>"tcp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.8/32"}], :ip_protocol=>"udp", :from_port=>0, :to_port=>65535},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.9/32"}], :ip_protocol=>"icmp", :from_port=>-1, :to_port=>-1},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.10/32"}], :ip_protocol=>"icmp", :from_port=>1, :to_port=>2},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.12/32"}], :ip_protocol=>"tcp", :from_port=>1012, :to_port=>1012},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.13/32"}], :ip_protocol=>"tcp", :from_port=>1013, :to_port=>1013},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.14/32"}], :ip_protocol=>"tcp", :from_port=>1014, :to_port=>1014},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.15/32"}], :ip_protocol=>"tcp", :from_port=>1117, :to_port=>1117},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.15/32"}], :ip_protocol=>"tcp", :from_port=>1015, :to_port=>1015},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.15/32"}], :ip_protocol=>"tcp", :from_port=>1016, :to_port=>1016},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.16/32"}, {:cidr_ip=>"10.0.0.26/32"}, {:cidr_ip=>"10.0.0.27/32"}], :ip_protocol=>"icmp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.21/32"}, {:cidr_ip=>"10.0.0.29/32"}], :ip_protocol=>"udp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.23/32"}], :ip_protocol=>"tcp", :from_port=>1020, :to_port=>1020},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.24/32"}], :ip_protocol=>"tcp", :from_port=>1021, :to_port=>1023},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.25/32"}], :ip_protocol=>"tcp", :from_port=>1024, :to_port=>1024},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.25/32"}], :ip_protocol=>"tcp", :from_port=>1025, :to_port=>1025},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.25/32"}], :ip_protocol=>"tcp", :from_port=>1125, :to_port=>1125},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1200, :to_port=>1200},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1201, :to_port=>1201},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1202, :to_port=>1202},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1203, :to_port=>1203},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1206, :to_port=>1206},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1208, :to_port=>1208},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1209, :to_port=>1209},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1210, :to_port=>1210}
          ],
          ip_permissions_list_egress: Set[
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.35/32"}, {:cidr_ip=>"10.0.0.36/32"}, {:cidr_ip=>"10.0.0.37/32"}, {:cidr_ip=>"10.0.0.38/32"}, {:cidr_ip=>"10.0.0.39/32"}, {:cidr_ip=>"10.0.0.40/32"}, {:cidr_ip=>"10.0.0.44/32"}, {:cidr_ip=>"10.0.0.52/32"}, {:cidr_ip=>"10.0.0.53/32"}, {:cidr_ip=>"10.0.0.63/32"}, {:cidr_ip=>"10.0.0.65/32"}, {:cidr_ip=>"10.0.0.66/32"}, {:cidr_ip=>"10.0.0.67/32"}], :ip_protocol=>"-1"},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.41/32"}], :ip_protocol=>"udp", :from_port=>0, :to_port=>65535},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.42/32"}], :ip_protocol=>"icmp", :from_port=>-1, :to_port=>-1},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.43/32"}], :ip_protocol=>"icmp", :from_port=>1, :to_port=>2},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.45/32"}], :ip_protocol=>"tcp", :from_port=>1012, :to_port=>1012},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.46/32"}], :ip_protocol=>"tcp", :from_port=>1013, :to_port=>1013},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.47/32"}], :ip_protocol=>"tcp", :from_port=>1014, :to_port=>1014},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.48/32"}], :ip_protocol=>"tcp", :from_port=>1015, :to_port=>1015},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.48/32"}], :ip_protocol=>"tcp", :from_port=>1016, :to_port=>1016},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.48/32"}], :ip_protocol=>"tcp", :from_port=>1117, :to_port=>1117},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.49/32"}, {:cidr_ip=>"10.0.0.59/32"}, {:cidr_ip=>"10.0.0.60/32"}], :ip_protocol=>"icmp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.50/32"}, {:cidr_ip=>"10.0.0.51/32"}, {:cidr_ip=>"10.0.0.55/32"}, {:cidr_ip=>"10.0.0.61/32"}, {:cidr_ip=>"10.0.0.64/32"}], :ip_protocol=>"tcp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.54/32"}, {:cidr_ip=>"10.0.0.62/32"}], :ip_protocol=>"udp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.56/32"}], :ip_protocol=>"tcp", :from_port=>1020, :to_port=>1020},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.57/32"}], :ip_protocol=>"tcp", :from_port=>1021, :to_port=>1023},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.58/32"}], :ip_protocol=>"tcp", :from_port=>1024, :to_port=>1024},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.58/32"}], :ip_protocol=>"tcp", :from_port=>1025, :to_port=>1025},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.58/32"}], :ip_protocol=>"tcp", :from_port=>1125, :to_port=>1125},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1200, :to_port=>1200},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1201, :to_port=>1201},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1202, :to_port=>1202},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1203, :to_port=>1203},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1206, :to_port=>1206},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1208, :to_port=>1208},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1209, :to_port=>1209},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1210, :to_port=>1210}
          ]
        ).and be_idempotent
      end

      it "can specify rules as a hash" do
        expect_recipe {
          aws_security_group 'test_sg' do
            # We need to define a list of ports and its easier to use a method than
            # have to add a new number when changing this test
            def counter()
              @ip_counter ||= 0
              @ip_counter += 1
            end

            vpc 'test_vpc'
            inbound_rules([
              { sources: "10.0.0.#{counter}/32", port_range: -1..-1, protocol: -1 },
              { sources: "10.0.0.#{counter}/32", port: -1, protocol: -1 },
              { sources: "10.0.0.#{counter}/32", port: 1002, protocol: -1 },
              { sources: "10.0.0.#{counter}/32", ports: 1003..1003, protocol: -1 },
              { sources: "10.0.0.#{counter}/32", port_range: 1004..1005, protocol: -1 },
              { sources: "10.0.0.#{counter}/32", port_range: [1006, 1007, 1108], protocol: -1 },
              # If the protocol isn't `-1` and you don't specify all the ports
              # aws wants `port_range` to be nil
              { sources: "10.0.0.#{counter}/32", ports: nil, protocol: :tcp },
              { sources: "10.0.0.#{counter}/32", port_range: 0..65535, protocol: :udp },
              { sources: "10.0.0.#{counter}/32", port_range: -1, protocol: :icmp },
              { sources: "10.0.0.#{counter}/32", port_range: 1..2, protocol: :icmp },
              { sources: "10.0.0.#{counter}/32", port_range: 1011, protocol: :any },
              { sources: "10.0.0.#{counter}/32", port_range: 1012, protocol: nil },
              { sources: "10.0.0.#{counter}/32", port: 1013 },
              { sources: "10.0.0.#{counter}/32", port: 1014..1014 },
              { sources: "10.0.0.#{counter}/32", port: [1015, 1016, 1117] },
              { sources: "10.0.0.#{counter}/32", port: :icmp },
              { sources: "10.0.0.#{counter}/32", port: 'tCp' },
              { sources: "10.0.0.#{counter}/32", port: nil },
              { sources: "10.0.0.#{counter}/32", protocol: -1 },
              { sources: "10.0.0.#{counter}/32", protocol: :any },
              { sources: "10.0.0.#{counter}/32", protocol: 'UDP' },
              { sources: "10.0.0.#{counter}/32", protocol: nil },
              { sources: "10.0.0.#{counter}/32", port_range: 1020 },
              { sources: "10.0.0.#{counter}/32", port_range: 1021..1023 },
              { sources: "10.0.0.#{counter}/32", port_range: [1024, 1025, 1125] },
              { sources: "10.0.0.#{counter}/32", port_range: :icmp },
              { sources: "10.0.0.#{counter}/32", port_range: 'Icmp' },
              { sources: "10.0.0.#{counter}/32", port_range: :tcp },
              { sources: "10.0.0.#{counter}/32", port_range: 'UDP' },
              { sources: "10.0.0.#{counter}/32", port_range: nil },
              { sources: "10.0.0.#{counter}/32", port_range: -1 },
              { sources: "10.0.0.#{counter}/32", port_range: :"-1" },
              { sources: ["10.0.0.#{counter}/32", "10.0.0.#{counter}/32"], port_range: :all },
              { sources: 'test_security_group', port: 1200 },
              { sources: test_security_group.aws_object.id, port: 1201 },
              { sources: test_security_group.aws_object, port: 1202 },
              { sources: test_security_group, port: 1203 },
              # cannot get the ID from the v1 api object
              #testloadbalancer.aws_object.id => 1205,
              { sources: testloadbalancer.aws_object, port: 1206 },
              # Cannot specify a LoadBalancer resource, only AwsLoadBalancer
              #testloadbalancer => 1207,
              { sources: {group_name: 'test_security_group'}, port: 1208 },
              { sources: {load_balancer: 'testloadbalancer'}, port: 1209 },
              { sources: {security_group: 'test_security_group'}, port: 1210 },
            ])
            outbound_rules([
              { port_range: -1..-1, protocol: -1, destinations: "10.0.0.#{counter}/32" },
              { port: -1, protocol: -1, destinations: "10.0.0.#{counter}/32" },
              { port: 1002, protocol: -1, destinations: "10.0.0.#{counter}/32" },
              { ports: 1003..1003, protocol: -1, destinations: "10.0.0.#{counter}/32" },
              { port_range: 1004..1005, protocol: -1, destinations: "10.0.0.#{counter}/32" },
              { port_range: [1006, 1007, 1108], protocol: -1, destinations: "10.0.0.#{counter}/32" },
              # If the protocol isn't `-1` and you don't specify all the ports
              # aws wants `port_range` to be nil{ ports: nil, protocol: :tcp } => "10.0.0.#{counter}/32",
              { port_range: 0..65535, protocol: :udp, destinations: "10.0.0.#{counter}/32" },
              { port_range: -1, protocol: :icmp, destinations: "10.0.0.#{counter}/32" },
              { port_range: 1..2, protocol: :icmp, destinations: "10.0.0.#{counter}/32" },
              { port_range: 1011, protocol: :any, destinations: "10.0.0.#{counter}/32" },
              { port_range: 1012, protocol: nil, destinations: "10.0.0.#{counter}/32" },
              { port: 1013, destinations: "10.0.0.#{counter}/32" },
              { port: 1014..1014, destinations: "10.0.0.#{counter}/32" },
              { port: [1015, 1016, 1117], destinations: "10.0.0.#{counter}/32" },
              { port: :icmp, destinations: "10.0.0.#{counter}/32" },
              { port: 'tCp', destinations: "10.0.0.#{counter}/32" },
              { port: nil, destinations: "10.0.0.#{counter}/32" },
              { protocol: -1, destinations: "10.0.0.#{counter}/32" },
              { protocol: :any, destinations: "10.0.0.#{counter}/32" },
              { protocol: 'UDP', destinations: "10.0.0.#{counter}/32" },
              { protocol: nil, destinations: "10.0.0.#{counter}/32" },
              { port_range: 1020, destinations: "10.0.0.#{counter}/32" },
              { port_range: 1021..1023, destinations: "10.0.0.#{counter}/32" },
              { port_range: [1024, 1025, 1125], destinations: "10.0.0.#{counter}/32" },
              { port_range: :icmp, destinations: "10.0.0.#{counter}/32" },
              { port_range: 'Icmp', destinations: "10.0.0.#{counter}/32" },
              { port_range: :tcp, destinations: "10.0.0.#{counter}/32" },
              { port_range: 'UDP', destinations: "10.0.0.#{counter}/32" },
              { port_range: nil, destinations: "10.0.0.#{counter}/32" },
              { port_range: -1, destinations: "10.0.0.#{counter}/32" },
              { port_range: :"-1", destinations: "10.0.0.#{counter}/32" },
              { port_range: :all, destinations: ["10.0.0.#{counter}/32", "10.0.0.#{counter}/32"] },
              { port: 1200, destinations: 'test_security_group' },
              { port: 1201, destinations: test_security_group.aws_object.id },
              { port: 1202, destinations: test_security_group.aws_object },
              { port: 1203, destinations: test_security_group },
              # cannot get the ID from the v1 api object
              #{ port: 1205, destinations: testloadbalancer.aws_object.id },
              { port: 1206, destinations: testloadbalancer.aws_object },
              # Cannot specify a LoadBalancer resource, only AwsLoadBalancer
              #{ port: 1207, destinations: testloadbalancer },
              { port: 1208, destinations: {group_name: 'test_security_group'} },
              { port: 1209, destinations: {load_balancer: 'testloadbalancer'} },
              { port: 1210, destinations: {security_group: 'test_security_group'} },
            ])
          end
        }.to create_an_aws_security_group('test_sg',
          vpc_id: test_vpc.aws_object.id,
          ip_permissions_list: Set[
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.1/32"}, {:cidr_ip=>"10.0.0.11/32"}, {:cidr_ip=>"10.0.0.19/32"}, {:cidr_ip=>"10.0.0.2/32"}, {:cidr_ip=>"10.0.0.20/32"}, {:cidr_ip=>"10.0.0.3/32"}, {:cidr_ip=>"10.0.0.32/32"}, {:cidr_ip=>"10.0.0.33/32"}, {:cidr_ip=>"10.0.0.34/32"}, {:cidr_ip=>"10.0.0.4/32"}, {:cidr_ip=>"10.0.0.5/32"}, {:cidr_ip=>"10.0.0.6/32"}], :ip_protocol=>"-1"},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.17/32"}, {:cidr_ip=>"10.0.0.18/32"}, {:cidr_ip=>"10.0.0.22/32"}, {:cidr_ip=>"10.0.0.28/32"}, {:cidr_ip=>"10.0.0.30/32"}, {:cidr_ip=>"10.0.0.31/32"}, {:cidr_ip=>"10.0.0.7/32"}], :ip_protocol=>"tcp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.8/32"}], :ip_protocol=>"udp", :from_port=>0, :to_port=>65535},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.9/32"}], :ip_protocol=>"icmp", :from_port=>-1, :to_port=>-1},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.10/32"}], :ip_protocol=>"icmp", :from_port=>1, :to_port=>2},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.12/32"}], :ip_protocol=>"tcp", :from_port=>1012, :to_port=>1012},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.13/32"}], :ip_protocol=>"tcp", :from_port=>1013, :to_port=>1013},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.14/32"}], :ip_protocol=>"tcp", :from_port=>1014, :to_port=>1014},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.15/32"}], :ip_protocol=>"tcp", :from_port=>1117, :to_port=>1117},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.15/32"}], :ip_protocol=>"tcp", :from_port=>1015, :to_port=>1015},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.15/32"}], :ip_protocol=>"tcp", :from_port=>1016, :to_port=>1016},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.16/32"}, {:cidr_ip=>"10.0.0.26/32"}, {:cidr_ip=>"10.0.0.27/32"}], :ip_protocol=>"icmp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.21/32"}, {:cidr_ip=>"10.0.0.29/32"}], :ip_protocol=>"udp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.23/32"}], :ip_protocol=>"tcp", :from_port=>1020, :to_port=>1020},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.24/32"}], :ip_protocol=>"tcp", :from_port=>1021, :to_port=>1023},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.25/32"}], :ip_protocol=>"tcp", :from_port=>1024, :to_port=>1024},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.25/32"}], :ip_protocol=>"tcp", :from_port=>1025, :to_port=>1025},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.25/32"}], :ip_protocol=>"tcp", :from_port=>1125, :to_port=>1125},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1200, :to_port=>1200},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1201, :to_port=>1201},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1202, :to_port=>1202},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1203, :to_port=>1203},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1206, :to_port=>1206},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1208, :to_port=>1208},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1209, :to_port=>1209},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1210, :to_port=>1210}
          ],
          ip_permissions_list_egress: Set[
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.35/32"}, {:cidr_ip=>"10.0.0.36/32"}, {:cidr_ip=>"10.0.0.37/32"}, {:cidr_ip=>"10.0.0.38/32"}, {:cidr_ip=>"10.0.0.39/32"}, {:cidr_ip=>"10.0.0.40/32"}, {:cidr_ip=>"10.0.0.44/32"}, {:cidr_ip=>"10.0.0.52/32"}, {:cidr_ip=>"10.0.0.53/32"}, {:cidr_ip=>"10.0.0.65/32"}, {:cidr_ip=>"10.0.0.66/32"}, {:cidr_ip=>"10.0.0.67/32"}], :ip_protocol=>"-1"},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.41/32"}], :ip_protocol=>"udp", :from_port=>0, :to_port=>65535},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.42/32"}], :ip_protocol=>"icmp", :from_port=>-1, :to_port=>-1},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.43/32"}], :ip_protocol=>"icmp", :from_port=>1, :to_port=>2},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.45/32"}], :ip_protocol=>"tcp", :from_port=>1012, :to_port=>1012},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.46/32"}], :ip_protocol=>"tcp", :from_port=>1013, :to_port=>1013},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.47/32"}], :ip_protocol=>"tcp", :from_port=>1014, :to_port=>1014},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.48/32"}], :ip_protocol=>"tcp", :from_port=>1015, :to_port=>1015},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.48/32"}], :ip_protocol=>"tcp", :from_port=>1016, :to_port=>1016},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.48/32"}], :ip_protocol=>"tcp", :from_port=>1117, :to_port=>1117},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.49/32"}, {:cidr_ip=>"10.0.0.59/32"}, {:cidr_ip=>"10.0.0.60/32"}], :ip_protocol=>"icmp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.50/32"}, {:cidr_ip=>"10.0.0.51/32"}, {:cidr_ip=>"10.0.0.55/32"}, {:cidr_ip=>"10.0.0.61/32"}, {:cidr_ip=>"10.0.0.63/32"}, {:cidr_ip=>"10.0.0.64/32"}], :ip_protocol=>"tcp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.54/32"}, {:cidr_ip=>"10.0.0.62/32"}], :ip_protocol=>"udp", :from_port=>0, :to_port=>0},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.56/32"}], :ip_protocol=>"tcp", :from_port=>1020, :to_port=>1020},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.57/32"}], :ip_protocol=>"tcp", :from_port=>1021, :to_port=>1023},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.58/32"}], :ip_protocol=>"tcp", :from_port=>1024, :to_port=>1024},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.58/32"}], :ip_protocol=>"tcp", :from_port=>1025, :to_port=>1025},
            {:groups=>[], :ip_ranges=>Set[{:cidr_ip=>"10.0.0.58/32"}], :ip_protocol=>"tcp", :from_port=>1125, :to_port=>1125},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1200, :to_port=>1200},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1201, :to_port=>1201},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1202, :to_port=>1202},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1203, :to_port=>1203},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1206, :to_port=>1206},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1208, :to_port=>1208},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1209, :to_port=>1209},
            {:groups=>[{:group_id=>test_security_group.aws_object.id}], :ip_ranges=>[], :ip_protocol=>"tcp", :from_port=>1210, :to_port=>1210}
          ]
        ).and be_idempotent
      end
    end

    with_aws "when narrowing from multiple VPCs" do
      aws_vpc 'test_vpc1' do
        cidr_block '10.0.0.0/24'
      end
      aws_vpc 'test_vpc2' do
        cidr_block '10.0.0.0/24'
      end
      aws_security_group 'test_sg' do
        vpc 'test_vpc1'
      end
      aws_security_group 'test_sg' do
        vpc 'test_vpc2'
      end

      # We need to manually delete these because the auto-delete
      # won't specify VPC
      after(:context) do
        converge {
          aws_security_group 'test_sg' do
            vpc 'test_vpc1'
            action :destroy
          end
          aws_security_group 'test_sg' do
            vpc 'test_vpc2'
            action :destroy
          end
        }
      end

      it "raises an error if it finds multiple security groups" do
        expect_converge {
          r = aws_security_group 'test_sg'
          r.aws_object
        }.to raise_error(::Chef::Provisioning::AWSDriver::Exceptions::MultipleSecurityGroupError)
      end

      it "correctly returns the security group when vpc is specified" do
        aws_obj = nil
        expect_converge {
          r = aws_security_group 'test_sg' do
            vpc 'test_vpc1'
          end
          aws_obj = r.aws_object
        }.to_not raise_error
        expect(aws_obj.vpc.tags['Name']).to eq('test_vpc1')
      end
    end

  end
end

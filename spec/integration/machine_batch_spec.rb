require "spec_helper"

describe Chef::Resource::MachineBatch do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: "foo", server_scope: :context do
    with_aws "with a VPC and a public subnet" do
      before :all do
        chef_config[:log_level] = :warn
      end

      purge_all
      setup_public_vpc

      azs = []
      driver.ec2.availability_zones.each { |az| azs << az }
      az = azs[1].name
      aws_subnet "test_subnet2" do
        vpc "test_vpc"
        cidr_block "10.0.1.0/24"
        availability_zone az
        map_public_ip_on_launch true
      end

      it "machine_batch creates multiple machines", :super_slow do
        expect_recipe do
          machine_batch "test_machines" do
            action :allocate
            (1..3).each do |i|
              machine "test_machine#{i}" do
                machine_options bootstrap_options: {
                  subnet_id: "test_public_subnet",
                  key_name: "test_key_pair"
                }, source_dest_check: false
              end
            end
            action :allocate
          end
        end.to create_an_aws_instance("test_machine1",
                                      source_dest_check: false).and create_an_aws_instance("test_machine2",
                                                                                           source_dest_check: false).and create_an_aws_instance("test_machine3",
                                                                                                                                                source_dest_check: false).and be_idempotent
      end

      it "machine_batch supports runtime machine_options", :super_slow do
        expect_recipe do
          subnets = %w{test_public_subnet test_subnet2}

          machine_batch "test_machines" do
            action :allocate
            (1..2).each do |i|
              machine "test_machine#{i}" do
                machine_options bootstrap_options: {
                  subnet_id: subnets[i - 1],
                  key_name: "test_key_pair"
                }, source_dest_check: (i == 1)
              end
            end
          end
        end.to create_an_aws_instance("test_machine1",
                                      subnet_id: test_public_subnet.aws_object.id,
                                      source_dest_check: true).and create_an_aws_instance("test_machine2",
                                                                                          subnet_id: test_subnet2.aws_object.id,
                                                                                          source_dest_check: false).and be_idempotent
      end
    end
  end
end

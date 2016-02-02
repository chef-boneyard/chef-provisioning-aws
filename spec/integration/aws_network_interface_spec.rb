describe "AwsNetworkInterface" do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do

      context "setting up public VPC" do

        setup_public_vpc

        it "creates an aws_network_interface resource with maximum attributes", :super_slow do
          expect_recipe {
            machine "test_machine" do
              machine_options bootstrap_options: {
                subnet_id: 'test_public_subnet',
                security_group_ids: ['test_security_group']
              }
              action :ready
            end

            aws_network_interface 'test_network_interface' do
              subnet 'test_public_subnet'
              private_ip_address '10.0.0.25'
              description "test_network_interface"
              security_groups ['test_security_group']
              machine "test_machine"
              device_index 1
            end
          }.to create_an_aws_instance('test_machine'
          ).and create_an_aws_network_interface('test_network_interface'
          ).and be_idempotent
        end

        it "creates aws_network_interface tags" do
          expect_recipe {
            aws_network_interface 'test_network_interface' do
              subnet 'test_public_subnet'
              aws_tags key1: "value"
            end
          }.to create_an_aws_network_interface('test_network_interface')
          .and have_aws_network_interface_tags('test_network_interface',
            {
              'Name' => 'test_network_interface',
              'key1' => 'value'
            }
          ).and be_idempotent
        end

        context "with existing tags" do
          aws_network_interface 'test_network_interface' do
            subnet 'test_public_subnet'
            aws_tags key1: "value"
          end

          it "updates aws_network_interface tags" do
            expect_recipe {
              aws_network_interface 'test_network_interface' do
                subnet 'test_public_subnet'
                aws_tags key1: "value2", key2: nil
              end
            }.to have_aws_network_interface_tags('test_network_interface',
              {
                'Name' => 'test_network_interface',
                'key1' => 'value2',
                'key2' => ''
              }
            ).and be_idempotent
          end

          it "removes all aws_network_interface tags except Name" do
            expect_recipe {
              aws_network_interface 'test_network_interface' do
                subnet 'test_public_subnet'
                aws_tags {}
              end
            }.to have_aws_network_interface_tags('test_network_interface',
              {
                'Name' => 'test_network_interface'
              }
            ).and be_idempotent
          end
        end

      end

    end
  end
end

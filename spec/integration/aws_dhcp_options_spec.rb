describe "AwsDhcpOptions" do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do

      it "creates an aws_dhcp_options resource with maximum attributes" do
        expect_recipe {
          aws_dhcp_options 'test-dhcp-options' do
            domain_name          'example.com'
            domain_name_servers  %w(8.8.8.8 8.8.4.4)
            ntp_servers          %w(8.8.8.8 8.8.4.4)
            netbios_name_servers %w(8.8.8.8 8.8.4.4)
            netbios_node_type    2
          end
        }.to create_an_aws_dhcp_options('test-dhcp-options', dhcp_configurations: [
          {key: "domain-name", values: [{value: "example.com"}]},
          {key: "domain-name-servers", values: [{value: "8.8.8.8"}, {value: "8.8.4.4"}]},
          {key: "ntp-servers", values: [{value: "8.8.8.8"}, {value: "8.8.4.4"}]}, 
          {key: "netbios-node-type", values: [{value: "2"}]}, 
          {key: "netbios-name-servers", values: [{value: "8.8.8.8"}, {value: "8.8.4.4"}]}
        ]).and be_idempotent
      end

      it "creates aws_dhcp_options tags" do
        expect_recipe {
          aws_dhcp_options 'test-dhcp-options' do
            aws_tags key1: "value"
          end
        }.to create_an_aws_dhcp_options('test-dhcp-options')
        .and have_aws_dhcp_options_tags('test-dhcp-options',
          {
            'Name' => 'test-dhcp-options',
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        aws_dhcp_options 'test-dhcp-options' do
          aws_tags key1: "value"
        end

        it "updates aws_dhcp_options tags" do
          expect_recipe {
            aws_dhcp_options 'test-dhcp-options' do
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_dhcp_options_tags('test-dhcp-options',
            {
              'Name' => 'test-dhcp-options',
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_dhcp_options tags except Name" do
          expect_recipe {
            aws_dhcp_options 'test-dhcp-options' do
              aws_tags Hash.new
            end
          }.to have_aws_dhcp_options_tags('test-dhcp-options',
            {
              'Name' => 'test-dhcp-options'
            }
          ).and be_idempotent
        end
      end

    end
  end
end

require 'spec_helper'

describe Chef::Resource::AwsVpc do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "When AWS has a DHCP options" do
      # Empty DHCP options for the purposes of associating
      aws_dhcp_options 'test_dhcp_options' do
      end

      context "Creating an aws_vpc" do
        it "aws_vpc 'vpc' with cidr_block '10.0.0.0/24' creates a VPC" do
          expect_recipe {
            aws_vpc 'test_vpc' do
              cidr_block '10.0.0.0/24'
            end
          }.to create_an_aws_vpc('test_vpc',
            cidr_block: '10.0.0.0/24',
            instance_tenancy: :default,
            state: :available,
            internet_gateway: nil
          ).and be_idempotent
        end

        it "aws_vpc 'vpc' with all attributes creates a VPC" do
          expect_recipe {
            aws_vpc 'test_vpc' do
              cidr_block '10.0.0.0/24'
              internet_gateway true
              instance_tenancy :dedicated
              main_routes '0.0.0.0/0' => :internet_gateway
              dhcp_options 'test_dhcp_options'
              enable_dns_support true
              enable_dns_hostnames true
            end
          }.to create_an_aws_vpc('test_vpc',
            cidr_block:       '10.0.0.0/24',
            instance_tenancy: :dedicated,
            dhcp_options_id:  test_dhcp_options.aws_object.id,
            state:            :available,
            "route_tables.main_route_table.routes" => [
              {
                destination_cidr_block: '10.0.0.0/24',
                target: { id: 'local' }
              },
              {
                destination_cidr_block: '0.0.0.0/0',
                target: an_instance_of(AWS::EC2::InternetGateway)
              }
            ],
            internet_gateway: an_instance_of(AWS::EC2::InternetGateway)
          ).and be_idempotent
        end
      end

      context "and an existing VPC with values filled in" do
        aws_vpc 'test_vpc' do
          cidr_block '10.0.0.0/24'
          internet_gateway true
          instance_tenancy :dedicated
          main_routes '0.0.0.0/0' => :internet_gateway
          dhcp_options 'test_dhcp_options'
          enable_dns_support true
          enable_dns_hostnames true
        end

        context "and a route table inside that VPC" do
          aws_route_table 'test_route_table' do
            vpc 'test_vpc'
          end

          it "aws_vpc can update the main_route_table to it" do
            expect_recipe {
              aws_vpc 'test_vpc' do
                main_route_table 'test_route_table'
              end
            }.to update_an_aws_vpc('test_vpc',
              "route_tables.main_route_table.id" => test_route_table.aws_object.id
            ).and be_idempotent
          end

          # Clean up the main route table association so we can cleanly delete
          before :each do
            @old_main = test_vpc.aws_object.route_tables.main_route_table
          end
          after :each do
            new_main = test_vpc.aws_object.route_tables.main_route_table
            if new_main != @old_main
              main_association = new_main.associations.select { |a| a.main? }.first
              if main_association
                test_vpc.aws_object.client.replace_route_table_association(
                  association_id: main_association.id,
                  route_table_id: @old_main.id)
              end
            end
          end
        end
      end

      it "aws_vpc 'vpc' with no attributes fails to create a VPC (must specify cidr_block)" do
        expect_recipe {
          aws_vpc 'test_vpc' do
          end
        }.to be_up_to_date
      end
    end
  end
end

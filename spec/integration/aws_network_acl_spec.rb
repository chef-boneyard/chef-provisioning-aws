require 'spec_helper'

describe Chef::Resource::AwsNetworkAcl do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC" do
      aws_vpc "test_vpc" do
        cidr_block '10.0.0.0/24'
        internet_gateway true
      end

      it "aws_network_acl 'test_network_acl' with no parameters except VPC creates a network acl" do
        expect_recipe {
          aws_network_acl 'test_network_acl' do
            vpc 'test_vpc'
          end
        }.to create_an_aws_network_acl('test_network_acl',
          vpc_id: test_vpc.aws_object.id,
        ).and be_idempotent
      end

      it "aws_network_acl 'test_network_acl' with all parameters creates a network acl" do
        expect_recipe {
          aws_network_acl 'test_network_acl' do
            vpc 'test_vpc'
            inbound_rules(
              [
                { rule_number: 100, rule_action: :deny, protocol: "-1", cidr_block: '10.0.0.0/24' },
                { rule_number: 200, rule_action: :allow, protocol: "-1", cidr_block: '0.0.0.0/0' },
                { rule_number: 300,
                  rule_action: :allow,
                  protocol: "6",
                  port_range:
                    {
                      :from => 22,
                      :to => 23
                    },
                  cidr_block: '172.31.0.0/22' }
              ]
            )
            outbound_rules(
              [
                { rule_number: 500, rule_action: :allow, protocol: "-1", cidr_block: '0.0.0.0/0' }
              ]
            )
          end
        }.to create_an_aws_network_acl('test_network_acl',
          vpc_id: test_vpc.aws_object.id,
          entries:
            [
              { :rule_number=>500, :protocol=>"-1", :rule_action=>"allow", :egress=>true, :cidr_block=>"0.0.0.0/0" },
              { :rule_number=>32767, :protocol=>"-1", :rule_action=>"deny", :egress=>true, :cidr_block=>"0.0.0.0/0" },
              { :rule_number=>100, :protocol=>"-1", :rule_action=>"deny", :egress=>false, :cidr_block=>"10.0.0.0/24" },
              { :rule_number=>200, :protocol=>"-1", :rule_action=>"allow", :egress=>false, :cidr_block=>"0.0.0.0/0" },
              { :rule_number=>300, :protocol=>"6", :rule_action=>"allow", :egress=>false, :cidr_block=>"172.31.0.0/22", :port_range=>{ :from=>22, :to=>23 } },
              { :rule_number=>32767, :protocol=>"-1", :rule_action=>"deny", :egress=>false, :cidr_block=>"0.0.0.0/0" }
            ]
        ).and be_idempotent
      end

      context 'when rules are empty' do
        aws_network_acl 'test_network_acl' do
          vpc 'test_vpc'
          inbound_rules(rule_number: 100, rule_action: :deny, protocol: "-1", cidr_block: '10.0.0.0/24')
          outbound_rules(rule_number: 500, rule_action: :allow, protocol: "-1", cidr_block: '0.0.0.0/0')
        end

        it "aws_network_acl 'test_network_acl' removes current rules" do
          expect_recipe {
            aws_network_acl 'test_network_acl' do
              vpc 'test_vpc'
              inbound_rules []
              outbound_rules []
            end
          }.to create_an_aws_network_acl('test_network_acl',
            vpc_id: test_vpc.aws_object.id,
            entries:
              [
                { :rule_number=>32767, :protocol=>"-1", :rule_action=>"deny", :egress=>true, :cidr_block=>"0.0.0.0/0" },
                { :rule_number=>32767, :protocol=>"-1", :rule_action=>"deny", :egress=>false, :cidr_block=>"0.0.0.0/0" }
              ]
          ).and be_idempotent
        end
      end

      context 'when rules are nil' do
        aws_network_acl 'test_network_acl' do
          vpc 'test_vpc'
          inbound_rules(rule_number: 100, rule_action: :deny, protocol: "-1", cidr_block: '10.0.0.0/24')
          outbound_rules(rule_number: 500, rule_action: :allow, protocol: "-1", cidr_block: '0.0.0.0/0')
        end

        it "aws_network_acl 'test_network_acl' with a nil rules array leaves current rules alone" do
          expect_recipe {
            aws_network_acl 'test_network_acl' do
              vpc 'test_vpc'
              inbound_rules nil
              outbound_rules nil
            end
          }.to match_an_aws_network_acl('test_network_acl',
            vpc_id: test_vpc.aws_object.id,
            entries:
              [
                { :rule_number=>500, :protocol=>"-1", :rule_action=>"allow", :egress=>true, :cidr_block=>"0.0.0.0/0" },
                { :rule_number=>32767, :protocol=>"-1", :rule_action=>"deny", :egress=>true, :cidr_block=>"0.0.0.0/0" },
                { :rule_number=>100, :protocol=>"-1", :rule_action=>"deny", :egress=>false, :cidr_block=>"10.0.0.0/24" },
                { :rule_number=>32767, :protocol=>"-1", :rule_action=>"deny", :egress=>false, :cidr_block=>"0.0.0.0/0" }
              ]
          ).and be_idempotent
        end
      end

      it "creates aws_network_acl tags" do
        expect_recipe {
          aws_network_acl 'test_network_acl' do
            vpc 'test_vpc'
            aws_tags key1: "value"
          end
        }.to create_an_aws_network_acl('test_network_acl')
        .and have_aws_network_acl_tags('test_network_acl',
          {
            'Name' => 'test_network_acl',
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        aws_network_acl 'test_network_acl' do
          vpc 'test_vpc'
          aws_tags key1: "value"
        end

        it "updates aws_network_acl tags" do
          expect_recipe {
            aws_network_acl 'test_network_acl' do
              vpc 'test_vpc'
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_network_acl_tags('test_network_acl',
            {
              'Name' => 'test_network_acl',
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_network_acl tags except Name" do
          expect_recipe {
            aws_network_acl 'test_network_acl' do
              vpc 'test_vpc'
              aws_tags({})
            end
          }.to have_aws_network_acl_tags('test_network_acl',
            {
              'Name' => 'test_network_acl'
            }
          ).and be_idempotent
        end
      end

    end
  end
end

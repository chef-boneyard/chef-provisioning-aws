require 'spec_helper'

describe Chef::Resource::LoadBalancer do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC and a public subnet" do

      purge_all
      setup_public_vpc

      it "creates a load_balancer with the maximum attributes" do
        expect_recipe {
          load_balancer 'test-load-balancer' do
            load_balancer_options({
              listeners: [{
                  :port => 80,
                  :protocol => :http,
                  :instance_port => 80,
                  :instance_protocol => :http,
              }],
              subnets: ["test_public_subnet"],
              security_groups: ["test_security_group"],
              health_check: {
                target: "HTTP:80/",
                interval: 10,
                timeout: 5,
                unhealthy_threshold: 2,
                healthy_threshold: 2
              }
              # 'only 1 of subnets or availability_zones may be specified'
              # availability_zones: [test_public_subnet.aws_object.availability_zone_name]
           })
          end
        }.to create_an_aws_load_balancer('test-load-balancer', {
          listeners: [{
              :port => 80,
              :protocol => :http,
              :instance_port => 80,
              :instance_protocol => :http,
          }],
          subnets: [test_public_subnet.aws_object],
          security_groups: [test_security_group.aws_object],
          health_check: {
            target: "HTTP:80/",
            interval: 10,
            timeout: 5,
            unhealthy_threshold: 2,
            healthy_threshold: 2
          }
        }
        ).and be_idempotent
      end

      it "creates load_balancer tags" do
        expect_recipe {
          load_balancer 'test-load-balancer' do
            aws_tags key1: "value"
            load_balancer_options :availability_zones => ['us-east-1d']
          end
        }.to create_an_aws_load_balancer('test-load-balancer')
        .and have_aws_load_balancer_tags('test-load-balancer',
          {
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        load_balancer 'test-load-balancer' do
          aws_tags key1: "value"
          load_balancer_options :availability_zones => ['us-east-1d']
        end

        it "updates aws_load_balancer tags" do
          expect_recipe {
            load_balancer 'test-load-balancer' do
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_load_balancer_tags('test-load-balancer',
            {
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_load_balancer tags" do
          expect_recipe {
            load_balancer 'test-load-balancer' do
              aws_tags Hash.new
            end
          }.to have_aws_load_balancer_tags('test-load-balancer',
            Hash.new
          ).and be_idempotent
        end
      end

    end
  end
end

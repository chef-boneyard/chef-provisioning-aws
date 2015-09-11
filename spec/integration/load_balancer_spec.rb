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
              security_groups: [default_security_group.id],
              health_check: {
                target: "HTTP:80/",
                interval: 10,
                timeout: 5,
                unhealthy_threshold: 2,
                healthy_threshold: 2
              }
           })
          end
        }.to create_an_aws_load_balancer('test-load-balancer', {
          listeners: [{
              :port => 80,
              :protocol => :http,
              :instance_port => 80,
              :instance_protocol => :http,
          }],
          subnets: [test_public_subnet.aws_object.id],
          security_groups: [default_security_group.id],
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

    end
  end
end

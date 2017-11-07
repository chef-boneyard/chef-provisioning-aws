require 'spec_helper'
require 'securerandom'

describe Chef::Resource::LoadBalancer do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC and a public subnet" do

      purge_all
      setup_public_vpc

      bucket_name = "chef.provisioning.test.#{SecureRandom.hex(8)}"
      aws_s3_bucket bucket_name do
        options acl: "public-read-write"
        recursive_delete true
      end

      cert_string = "-----BEGIN CERTIFICATE-----\nMIIDlDCCAnygAwIBAgIJAOR3PCV+XjkpMA0GCSqGSIb3DQEBBQUAMDoxCzAJBgNV\nBAYTAlVTMRMwEQYDVQQIEwpTb21lLVN0YXRlMRYwFAYDVQQKEw1DaGVmIFNvZnR3\nYXJlMB4XDTE2MDgwMzE2MTUwNVoXDTQzMTIyMDE2MTUwNVowOjELMAkGA1UEBhMC\nVVMxEzARBgNVBAgTClNvbWUtU3RhdGUxFjAUBgNVBAoTDUNoZWYgU29mdHdhcmUw\nggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDPiAXE1LPDDBithNM4I1VA\nv9qCkheZAoq2QTv5Sn7Bo51JHaJm+Bzh+jACpBDl21W26vosQDYsOUsgsT7syGUH\nE9zdX32WGLmn8+94YI8juT2xhPSI8nCKq9b7+cKj3dCg2lRQOBvpalP9EQ0URKf3\n2dMTk2PE3HnrRqpLEA8dOiAkTPfALxzqZBCgA065fM1vjXC84JQjtOS7voBD24QI\nVSO1ilenHySiZpgA+3DOvzssZ1LKwTvmuhqB7CzYzMAmAYbXqhQGwnNPjkyUjJCi\ns3cCOhnd/N7qSik6EBZ5hQzrWvBOrsm0te0Eb/3InNN395ZTxzhxIrzN4/Hjxf1N\nAgMBAAGjgZwwgZkwHQYDVR0OBBYEFOxyNX8IT5AqXXIlIx49yxf/IYLOMGoGA1Ud\nIwRjMGGAFOxyNX8IT5AqXXIlIx49yxf/IYLOoT6kPDA6MQswCQYDVQQGEwJVUzET\nMBEGA1UECBMKU29tZS1TdGF0ZTEWMBQGA1UEChMNQ2hlZiBTb2Z0d2FyZYIJAOR3\nPCV+XjkpMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEBALagR0Da4UgO\nQap+dbZV6w/xsGuDE8nmb+nT40e5t06H1dlJtqv1KQiZvTE2F4qdb3gNTLriST5d\nIBgb9NvfVwkUx5J/PNJPwGkLGLgPk7SdGZeIht081wm/OQ/EcadAx8hI778AR877\ng6ni7QG+uJsIsuAnsTWC7T+/QNkVp0WvPw2CWPgmWm5Hg4zK6KUMQ5zKi91mMkzv\nclUpgp1qdQOwbS9tDygz5MBsThdsxKZ90I8AxDsPNGFxDZJg9Dj2IvETC3pVvGlh\nMlr7hdYITWdCEPEntDKPA4OOqpJhcfxGbN+Ze/XhpYbqOG9aPYU6w4oqcmjinf+j\nySQz2RMQ9To=\n-----END CERTIFICATE-----"
      private_key_string = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAz4gFxNSzwwwYrYTTOCNVQL/agpIXmQKKtkE7+Up+waOdSR2i\nZvgc4fowAqQQ5dtVtur6LEA2LDlLILE+7MhlBxPc3V99lhi5p/PveGCPI7k9sYT0\niPJwiqvW+/nCo93QoNpUUDgb6WpT/RENFESn99nTE5NjxNx560aqSxAPHTogJEz3\nwC8c6mQQoANOuXzNb41wvOCUI7Tku76AQ9uECFUjtYpXpx8komaYAPtwzr87LGdS\nysE75roagews2MzAJgGG16oUBsJzT45MlIyQorN3AjoZ3fze6kopOhAWeYUM61rw\nTq7JtLXtBG/9yJzTd/eWU8c4cSK8zePx48X9TQIDAQABAoIBAA8teoaHq9Hy+4cN\nNMlhRCXlIhz0hEdLeUuU/8benOCaj7E+OpdfQ/V+763xw86buOwUyVEdLRkU45qz\ne8+jZEgdOsTx6+RjUIio/XWHUlChhpKKD7xIRtTNdn6dKJAFc/GfphTr1Za/kP7s\nFVHLJ6Gny5kd6WkHWt9LHr84oHJZoSjR6YDYdSTL+NtVTwqsKj4EfNY8JAPJI/xI\n9A9t57pvXzwdiya/vXPGytgwkHC/HHWp2sgFvKtJUzuGH0ETDlys9mvXoVQeZ0d9\njhzwIwWAoyvTY9FsUBTCD0aO8r2ylsDVIo2b2cEAZ0Z77OGMUt4sock88sDIICnO\nZVjhV50CgYEA8hKTHpI5ENFvYrTckrc+PnPw7B7xHCCB84ut/CiwzawYRjUx/mtm\nCYYR1xAXdEFrBC21i4Ri8LAIrAQiFGydg2oh4ZQcnEMGKZ0F2VXlsidVNN2tW/50\n8kEaPHPVeP6Trt2kPtpQnhDcuQXbPmOgPBIY2j6nu/Go25e8eICkfhsCgYEA23iy\n8Og1SWZlV5b3ZFyolZiZ9kp0cwyXUGWxUZyw33gBmK6BFkscflI1vfNutxnTDjNl\nALLRoAeIApvXTMFOMUPJsDk90pO7rdlfLznU27lKPyCDkvDGmjCvGGDXrnvi+cc3\ngB3ERfrLJCMoMk9lyg7/KEzzsIjvtTRO79atCLcCgYAGT/+wI2YDj0KVU1wRI2An\nJsTYk3H8Jsjcvf66faEmq98yLX7xQIG3q9xZPF0wNeiBgmOikMA3wI9pVO5ClBaD\nb8gUZtVcKc9GVIbrhPbpb2ckasdzh64rBxGVE/w0HIdjXvpCfVTu2ke3N3ThKp3q\nExq8zjd3ijS6DTnn9orTkwKBgQCxVwpgl4HXWaIx8I7ezfB7UN+3n9oQzO/HyyRI\n6fAR4oqHsRolxXO0rwE2B+pCkd907hqDQfsY8Hz6fqquHtTsAfaLKvXFnhJdG/RJ\n2NUi5soT0FYA+gXAue4CKN6e4wQ5CLzUDTl3wns7LB1i6b06VHvhOK0AzOXE6guO\nyUzwaQKBgDCrGz6IrxEUWl6C14xNNRZBvYTY9oCQpUnup1gMxATJZm4KelKvtKz2\nU1MXpc1i395e+E+tjNAQg0JcBmwkHOMl8c/oAESWPxi11ezalGtUXjIgjBkqqNUE\n/uFqRpNFGwI09JolIqhBTgPWFq6MuuPDJ9IIGJZDQoGEBKmu0k2r\n-----END RSA PRIVATE KEY-----"

      aws_server_certificate "load_balancer_cert" do
        certificate_body cert_string
        private_key private_key_string
      end

      aws_server_certificate "load_balancer_cert_2" do
        certificate_body cert_string
        private_key private_key_string
      end

      it "creates a load_balancer with the maximum attributes" do
        expect_recipe {
          load_balancer 'test-load-balancer' do
            load_balancer_options({
              listeners: [
                {
                  :port => 80,
                  :protocol => :http,
                  :instance_port => 80,
                  :instance_protocol => :http
                },
                {
                  :port => 443,
                  :protocol => :https,
                  :instance_port => 81,
                  :instance_protocol => :http,
                  :ssl_certificate_id => load_balancer_cert.aws_object.server_certificate_metadata.arn
                }
              ],
              subnets: ["test_public_subnet"],
              security_groups: ["test_security_group"],
              health_check: {
                target: "HTTP:80/",
                interval: 10,
                timeout: 5,
                unhealthy_threshold: 2,
                healthy_threshold: 2
              },
              sticky_sessions: {
                cookie_name: 'test-cookie-name',
                ports: [80, 443]
              },
              scheme: "internal",
              attributes: {
                cross_zone_load_balancing: {
                  enabled: true
                },
                access_log: {
                  enabled: true,
                  s3_bucket_name: bucket_name,
                  emit_interval: 5,
                  s3_bucket_prefix: "AccessLogPrefix",
                },
                connection_draining: {
                  enabled: true,
                  timeout: 1,
                },
                connection_settings: {
                  idle_timeout: 1,
                },
                # Don't know what can go here
                # additional_attributes: [
                #   {
                #     key: "StringVal",
                #     value: "StringVal",
                #   },
                # ]
              }
              # 'only 1 of subnets or availability_zones may be specified'
              # availability_zones: [test_public_subnet.aws_object.availability_zone_name]
           })
          end
        }.to create_an_aws_load_balancer('test-load-balancer',
          driver.elb_client.describe_load_balancers(load_balancer_names: ["test-load-balancer"])[0][0]
        ).and be_idempotent
        expect(
          driver.elb_client.describe_load_balancer_attributes(load_balancer_name: "test-load-balancer").to_h
        ).to eq(load_balancer_attributes: {
          cross_zone_load_balancing: {enabled: true},
          access_log: {
            enabled: true,
            s3_bucket_name: bucket_name,
            emit_interval: 5,
            s3_bucket_prefix: "AccessLogPrefix",
          },
          connection_draining: {
            enabled: true,
            timeout: 1,
          },
          connection_settings: {
            idle_timeout: 1,
          }
        })
        stickiness_policy = driver.elb_client.describe_load_balancer_policies(load_balancer_name: 'test-load-balancer')[:policy_descriptions].detect { |pd| pd[:policy_type_name] == 'AppCookieStickinessPolicyType' }.to_h
        expect(stickiness_policy).to eq(
          {
            policy_attribute_descriptions: [
              {attribute_value: "test-cookie-name", attribute_name: "CookieName"}
          ],
            policy_type_name: "AppCookieStickinessPolicyType",
            policy_name: "test-load-balancer-sticky-session-policy"
          }
        )

        listener_descriptions = driver.elb_client.describe_load_balancers(load_balancer_names: ['test-load-balancer'])[:load_balancer_descriptions][0][:listener_descriptions]
        expect(listener_descriptions.size).to eql(2)
        http_listener = listener_descriptions.detect { |ld| ld[:listener][:load_balancer_port] == 80 }
        https_listener = listener_descriptions.detect { |ld| ld[:listener][:load_balancer_port] == 443 }
        expect(http_listener[:policy_names]).to include('test-load-balancer-sticky-session-policy')
        expect(https_listener[:policy_names]).to include('test-load-balancer-sticky-session-policy')
      end

      context 'with an existing load balancer' do
        aws_security_group 'test_security_group2' do
          vpc 'test_vpc'
          inbound_rules '0.0.0.0/0' => [ 22, 80 ]
          outbound_rules [ 22, 80 ] => '0.0.0.0/0'
        end

        azs = driver.ec2_client.describe_availability_zones.availability_zones.map {|r| r.zone_name}
        aws_subnet 'test_public_subnet2' do
          vpc 'test_vpc'
          map_public_ip_on_launch true
          cidr_block '10.0.1.0/24'
          # This subnet _must_ be in a different availability_zone than the existing one
          availability_zone azs.last
        end

        load_balancer 'test-load-balancer' do
          load_balancer_options({
            listeners: [{
                :port => 80,
                :protocol => :http,
                :instance_port => 80,
                :instance_protocol => :http,
            },
            {
                :port => 8443,
                :protocol => :https,
                :instance_port => 80,
                :instance_protocol => :http,
                :ssl_certificate_id => load_balancer_cert.aws_object.server_certificate_metadata.arn
            }],
            subnets: ["test_public_subnet"],
            security_groups: ["test_security_group"],
            health_check: {
              target: "HTTP:80/",
              interval: 10,
              timeout: 5,
              unhealthy_threshold: 2,
              healthy_threshold: 2
            },
            sticky_sessions: {
              cookie_name: 'test-cookie-name',
              ports: [80]
            },
            scheme: "internal",
            attributes: {
              cross_zone_load_balancing: {
                enabled: true
              },
              access_log: {
                enabled: true,
                s3_bucket_name: bucket_name,
                emit_interval: 5,
                s3_bucket_prefix: "AccessLogPrefix",
              },
              connection_draining: {
                enabled: true,
                timeout: 1,
              },
              connection_settings: {
                idle_timeout: 1,
              }
            }
          })
        end

        it 'updates all available attributes' do
          expect_recipe {
            load_balancer 'test-load-balancer' do
              load_balancer_options({
                listeners: [{
                    :port => 443,
                    :protocol => :https,
                    :instance_port => 8080,
                    :instance_protocol => :http,
                    :ssl_certificate_id => load_balancer_cert.aws_object.server_certificate_metadata.arn
                },
                {
                    :port => 8443,
                    :protocol => :https,
                    :instance_port => 80,
                    :instance_protocol => :http,
                    :ssl_certificate_id => load_balancer_cert_2.aws_object.server_certificate_metadata.arn
                }],
                subnets: ["test_public_subnet2"],
                security_groups: ["test_security_group2"],
                health_check: {
                  target: "HTTP:8080/",
                  interval: 15,
                  timeout: 4,
                  unhealthy_threshold: 3,
                  healthy_threshold: 3
                },
                sticky_sessions: {
                  cookie_name: 'test-cookie-name2',
                  ports: [443]
                },
                # scheme is immutable, we cannot update it
                #scheme: "internet-facing",
                attributes: {
                  cross_zone_load_balancing: {
                    enabled: false
                  },
                  access_log: {
                    enabled: true,
                    s3_bucket_name: bucket_name,
                    emit_interval: 60,
                    s3_bucket_prefix: "AccessLogPrefix2",
                  },
                  connection_draining: {
                    enabled: true,
                    timeout: 10,
                  },
                  connection_settings: {
                    idle_timeout: 10,
                  }
                }
             })
            end
          }.to update_an_aws_load_balancer('test-load-balancer', driver.elb_client.describe_load_balancers(load_balancer_names: ["test-load-balancer"])[0][0]).and be_idempotent

          expect(
            driver.elb_client.describe_load_balancer_attributes(load_balancer_name: "test-load-balancer").to_h
          ).to eq(load_balancer_attributes: {
            cross_zone_load_balancing: {
              enabled: false
            },
            access_log: {
              enabled: true,
              s3_bucket_name: bucket_name,
              emit_interval: 60,
              s3_bucket_prefix: "AccessLogPrefix2",
            },
            connection_draining: {
              enabled: true,
              timeout: 10,
            },
            connection_settings: {
              idle_timeout: 10,
            }
          })

          stickiness_policy = driver.elb_client.describe_load_balancer_policies(load_balancer_name: 'test-load-balancer')[:policy_descriptions].detect { |pd| pd[:policy_type_name] == 'AppCookieStickinessPolicyType' }.to_h
          expect(stickiness_policy).to eq(
            {
              policy_attribute_descriptions: [
                {attribute_value: "test-cookie-name2", attribute_name: "CookieName"}
            ],
              policy_type_name: "AppCookieStickinessPolicyType",
              policy_name: "test-load-balancer-sticky-session-policy"
            }
          )

          listener_descriptions = driver.elb_client.describe_load_balancers(load_balancer_names: ['test-load-balancer'])[:load_balancer_descriptions][0][:listener_descriptions]
          expect(listener_descriptions.size).to eql(2)
          https_listener = listener_descriptions.detect { |ld| ld[:listener][:load_balancer_port] == 443 }
          expect(https_listener[:policy_names]).to include('test-load-balancer-sticky-session-policy')
        end
      end

      context 'when there are machines', :super_slow do
        [1, 2].each do |i|
          machine "test_load_balancer_machine#{i}" do
            machine_options bootstrap_options: {
              subnet_id: "test_public_subnet",
              security_group_ids: ["test_security_group"]
            }
            action :allocate
          end
        end

        it "creates a load_balancer and assigns machine1" do
          expect_recipe {
            load_balancer 'test-load-balancer' do
              load_balancer_options({
                subnets: ["test_public_subnet"],
                security_groups: ["test_security_group"]
              })
              machines ['test_load_balancer_machine1']
            end
          }.to create_an_aws_load_balancer('test-load-balancer') { |aws_object|
            ids = aws_object.instances.map {|i| i.instance_id}
            expect([test_load_balancer_machine1.aws_object.id]).to eq(ids)
          }.and be_idempotent
        end

        it "can reference machines by name or id" do
          expect_recipe {
            load_balancer 'test-load-balancer' do
              load_balancer_options({
                subnets: ["test_public_subnet"],
                security_groups: ["test_security_group"]
              })
              machines ['test_load_balancer_machine1', test_load_balancer_machine2.aws_object.id]
            end
          }.to create_an_aws_load_balancer('test-load-balancer') { |aws_object|
            ids = aws_object.instances.map {|i| i.instance_id}
            expect(ids.to_set).to eq([test_load_balancer_machine1.aws_object.id, test_load_balancer_machine2.aws_object.id].to_set)
          }.and be_idempotent
        end

        context "with an existing load_balancer with machine1 attached" do
          load_balancer 'test-load-balancer' do
            load_balancer_options({
              subnets: ["test_public_subnet"],
              security_groups: ["test_security_group"]
            })
            machines ['test_load_balancer_machine1']
          end

          it "updates the attached machine to machine2" do
            expect_recipe {
              load_balancer 'test-load-balancer' do
                load_balancer_options({
                  subnets: ["test_public_subnet"],
                  security_groups: ["test_security_group"]
                })
                machines ['test_load_balancer_machine2']
              end
            }.to match_an_aws_load_balancer('test-load-balancer') { |aws_object|
              ids = aws_object.instances.map {|i| i.instance_id}
              expect([test_load_balancer_machine2.aws_object.id]).to eq(ids)
            }.and be_idempotent
          end
        end
      end

      context 'with an existing load_balancer' do
        load_balancer 'test-load-balancer' do
          load_balancer_options subnets: ["test_public_subnet"]
        end

        it 'successfully deletes the load_balancer with the :destroy action' do
          r = recipe {
            load_balancer 'test-load-balancer' do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_load_balancer('test-load-balancer').and be_idempotent
        end
      end

      it "creates load_balancer tags" do
        expect_recipe {
          load_balancer 'test-load-balancer' do
            aws_tags key1: "value"
            load_balancer_options subnets: ["test_public_subnet"]
          end
        }.to create_an_aws_load_balancer('test-load-balancer',
          driver.elb_client.describe_load_balancers(load_balancer_names: ["test-load-balancer"])[0][0])
        .and have_aws_load_balancer_tags('test-load-balancer',
          {
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        load_balancer 'test-load-balancer' do
          aws_tags key1: "value"
          load_balancer_options subnets: ["test_public_subnet"]
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

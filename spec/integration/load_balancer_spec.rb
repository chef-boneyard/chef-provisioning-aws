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

      cert_string = "-----BEGIN CERTIFICATE-----\nMIIDejCCAmICCQCpupMy/LKfLTANBgkqhkiG9w0BAQUFADB/MQswCQYDVQQGEwJV\nUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHU2VhdHRsZTENMAsGA1UE\nChMEQ2hlZjEMMAoGA1UECxMDRGV2MQ4wDAYDVQQDEwVUeWxlcjEcMBoGCSqGSIb3\nDQEJARYNdHlsZXJAY2hlZi5pbzAeFw0xNTA4MDQwMDI1NDFaFw0xNjA4MDMwMDI1\nNDFaMH8xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH\nEwdTZWF0dGxlMQ0wCwYDVQQKEwRDaGVmMQwwCgYDVQQLEwNEZXYxDjAMBgNVBAMT\nBVR5bGVyMRwwGgYJKoZIhvcNAQkBFg10eWxlckBjaGVmLmlvMIIBIjANBgkqhkiG\n9w0BAQEFAAOCAQ8AMIIBCgKCAQEAz4gFxNSzwwwYrYTTOCNVQL/agpIXmQKKtkE7\n+Up+waOdSR2iZvgc4fowAqQQ5dtVtur6LEA2LDlLILE+7MhlBxPc3V99lhi5p/Pv\neGCPI7k9sYT0iPJwiqvW+/nCo93QoNpUUDgb6WpT/RENFESn99nTE5NjxNx560aq\nSxAPHTogJEz3wC8c6mQQoANOuXzNb41wvOCUI7Tku76AQ9uECFUjtYpXpx8komaY\nAPtwzr87LGdSysE75roagews2MzAJgGG16oUBsJzT45MlIyQorN3AjoZ3fze6kop\nOhAWeYUM61rwTq7JtLXtBG/9yJzTd/eWU8c4cSK8zePx48X9TQIDAQABMA0GCSqG\nSIb3DQEBBQUAA4IBAQBXJQSpDkjxyljnSWjBur4XikLlFuEpdAdu0MILM3GnS3rT\ntoCVPG2U1d+KkhYG0Y9TBxHpK+3lDGYNyFYJN0STzL4cFzMgQlmZKFhVi/YJWKYO\nj9baIB3dy2k8b2XdDe3WxyycQpHjHhFPqpOTMGNV/1PwJNZGQEjc/svr8EalxvZB\neMb3Kk94K7yohvhT+Ze//rr4ArlM1zvEv3QMwSuyJBA2gtH7FgFKWohZnubW+3uc\n9W/Ux/3O1+BKDWp6zyqn/b2SSF51Jt3tSCF+hIMKYeJnJojY/AF9tQ+DtE8EKYRD\n/qzXX2MQLbhm1AzLt4PN63r96ADYlHhOJGNa9ocS\n-----END CERTIFICATE-----"
      private_key_string = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAz4gFxNSzwwwYrYTTOCNVQL/agpIXmQKKtkE7+Up+waOdSR2i\nZvgc4fowAqQQ5dtVtur6LEA2LDlLILE+7MhlBxPc3V99lhi5p/PveGCPI7k9sYT0\niPJwiqvW+/nCo93QoNpUUDgb6WpT/RENFESn99nTE5NjxNx560aqSxAPHTogJEz3\nwC8c6mQQoANOuXzNb41wvOCUI7Tku76AQ9uECFUjtYpXpx8komaYAPtwzr87LGdS\nysE75roagews2MzAJgGG16oUBsJzT45MlIyQorN3AjoZ3fze6kopOhAWeYUM61rw\nTq7JtLXtBG/9yJzTd/eWU8c4cSK8zePx48X9TQIDAQABAoIBAA8teoaHq9Hy+4cN\nNMlhRCXlIhz0hEdLeUuU/8benOCaj7E+OpdfQ/V+763xw86buOwUyVEdLRkU45qz\ne8+jZEgdOsTx6+RjUIio/XWHUlChhpKKD7xIRtTNdn6dKJAFc/GfphTr1Za/kP7s\nFVHLJ6Gny5kd6WkHWt9LHr84oHJZoSjR6YDYdSTL+NtVTwqsKj4EfNY8JAPJI/xI\n9A9t57pvXzwdiya/vXPGytgwkHC/HHWp2sgFvKtJUzuGH0ETDlys9mvXoVQeZ0d9\njhzwIwWAoyvTY9FsUBTCD0aO8r2ylsDVIo2b2cEAZ0Z77OGMUt4sock88sDIICnO\nZVjhV50CgYEA8hKTHpI5ENFvYrTckrc+PnPw7B7xHCCB84ut/CiwzawYRjUx/mtm\nCYYR1xAXdEFrBC21i4Ri8LAIrAQiFGydg2oh4ZQcnEMGKZ0F2VXlsidVNN2tW/50\n8kEaPHPVeP6Trt2kPtpQnhDcuQXbPmOgPBIY2j6nu/Go25e8eICkfhsCgYEA23iy\n8Og1SWZlV5b3ZFyolZiZ9kp0cwyXUGWxUZyw33gBmK6BFkscflI1vfNutxnTDjNl\nALLRoAeIApvXTMFOMUPJsDk90pO7rdlfLznU27lKPyCDkvDGmjCvGGDXrnvi+cc3\ngB3ERfrLJCMoMk9lyg7/KEzzsIjvtTRO79atCLcCgYAGT/+wI2YDj0KVU1wRI2An\nJsTYk3H8Jsjcvf66faEmq98yLX7xQIG3q9xZPF0wNeiBgmOikMA3wI9pVO5ClBaD\nb8gUZtVcKc9GVIbrhPbpb2ckasdzh64rBxGVE/w0HIdjXvpCfVTu2ke3N3ThKp3q\nExq8zjd3ijS6DTnn9orTkwKBgQCxVwpgl4HXWaIx8I7ezfB7UN+3n9oQzO/HyyRI\n6fAR4oqHsRolxXO0rwE2B+pCkd907hqDQfsY8Hz6fqquHtTsAfaLKvXFnhJdG/RJ\n2NUi5soT0FYA+gXAue4CKN6e4wQ5CLzUDTl3wns7LB1i6b06VHvhOK0AzOXE6guO\nyUzwaQKBgDCrGz6IrxEUWl6C14xNNRZBvYTY9oCQpUnup1gMxATJZm4KelKvtKz2\nU1MXpc1i395e+E+tjNAQg0JcBmwkHOMl8c/oAESWPxi11ezalGtUXjIgjBkqqNUE\n/uFqRpNFGwI09JolIqhBTgPWFq6MuuPDJ9IIGJZDQoGEBKmu0k2r\n-----END RSA PRIVATE KEY-----"

      aws_server_certificate "load_balancer_cert" do
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
                  :ssl_certificate_id => load_balancer_cert.aws_object.arn
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
        }.to create_an_aws_load_balancer('test-load-balancer', {
          listeners: [
            {
              :port => 80,
              :protocol => :http,
              :instance_port => 80,
              :instance_protocol => :http,
            },
            {
              :port => 443,
              :protocol => :https,
              :instance_port => 81,
              :instance_protocol => :http,
              :server_certificate => {arn: load_balancer_cert.aws_object.arn}
            }
          ],
          subnets: [test_public_subnet.aws_object],
          security_groups: [test_security_group.aws_object],
          health_check: {
            target: "HTTP:80/",
            interval: 10,
            timeout: 5,
            unhealthy_threshold: 2,
            healthy_threshold: 2
          },
          scheme: "internal"
        }).and be_idempotent
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
                    :ssl_certificate_id => load_balancer_cert.aws_object.arn
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
          }.to update_an_aws_load_balancer('test-load-balancer', {
            listeners: [{
                :port => 443,
                :protocol => :https,
                :instance_port => 8080,
                :instance_protocol => :http,
                :server_certificate => {arn: load_balancer_cert.aws_object.arn}
            }],
            subnets: [test_public_subnet2.aws_object],
            security_groups: [test_security_group2.aws_object],
            health_check: {
              target: "HTTP:8080/",
              interval: 15,
              timeout: 4,
              unhealthy_threshold: 3,
              healthy_threshold: 3
            },
            scheme: "internal"
          }).and be_idempotent
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
          }.to create_an_aws_load_balancer('test-load-balancer',
            :instances => [{id: test_load_balancer_machine1.aws_object.id}]
          ).and be_idempotent
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
          }.to create_an_aws_load_balancer('test-load-balancer',
            :instances => [{id: test_load_balancer_machine1.aws_object.id}, {id: test_load_balancer_machine2.aws_object.id}]
          ).and be_idempotent
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
            }.to match_an_aws_load_balancer('test-load-balancer',
              :instances => [{id: test_load_balancer_machine2.aws_object.id}]
            ).and be_idempotent
          end
        end
      end

      context 'with an existing load_balancer' do
        load_balancer 'test-load-balancer' do
          load_balancer_options({
            subnets: ["test_public_subnet"]
          })
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

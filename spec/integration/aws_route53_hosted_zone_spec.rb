require 'spec_helper'

describe Chef::Resource::AwsRoute53HostedZone do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do

      context "aws_route53_hosted_zone" do

        # for the occasional spec where the test zone won't be automatically deleted, the spec can set
        # @zone_to_delete to communicate the zone name to the 'after' block. (this can't be done just with
        # let-vars because attribute values in dependent RecordSet resources have to be hard-coded.)
        let(:zone_to_delete) { @zone_to_delete }

        after(:example) {
          if zone_to_delete
            converge {
              aws_route53_hosted_zone zone_to_delete do
                action :destroy
              end
            }
          end
        }

        let(:zone_name) { "aws-spec-#{Time.now.to_i}.com" }

        context ":create" do
          it "creates a hosted zone without attributes" do
            expect(recipe {
              aws_route53_hosted_zone zone_name
            }).to create_an_aws_route53_hosted_zone(zone_name).and be_idempotent
          end

          it "creates a hosted zone with attributes" do
            test_comment = "Test comment for spec."

            expect_recipe {
              aws_route53_hosted_zone zone_name do
                comment test_comment
              end
            }.to create_an_aws_route53_hosted_zone(zone_name,
                                                   config: { comment: test_comment }).and be_idempotent
          end

          # we don't want to go overboard testing all our validations, but this is the one that can cause the
          # most difficult user confusion, and AWS won't catch it.
          it "crashes if the zone name has a trailing dot" do
            expect_converge {
              aws_route53_hosted_zone "#{zone_name}."
            }.to raise_error(Chef::Exceptions::ValidationFailed, /domain name cannot end with a dot/)
          end

          it "updates the zone comment" do
            expected_comment = "Updated comment."

            expect_recipe {
              aws_route53_hosted_zone zone_name do
                comment "Initial comment."
              end
              aws_route53_hosted_zone zone_name do
                comment expected_comment
              end
            }.to create_an_aws_route53_hosted_zone(zone_name,
                                                   config: { comment: expected_comment }).and be_idempotent
          end

          it "updates the zone comment when none is given" do
            expect_recipe {
              aws_route53_hosted_zone zone_name do
                comment "Initial comment."
              end
              aws_route53_hosted_zone zone_name do
              end
            }.to create_an_aws_route53_hosted_zone(zone_name,
                                                   config: { comment: nil }).and be_idempotent
          end
        end

        context "RecordSets" do
          let(:sdk_cname_rr) {
            {
              name: "some-host.feegle.com.",  # AWS adds the trailing dot.
              type: "CNAME",
              ttl: 3600,
              resource_records: [{ value: "some-other-host" }],
            }
          }

          it "crashes on duplicate RecordSets" do
            expect_converge {
              aws_route53_hosted_zone "chasm.com" do
                record_sets {
                  aws_route53_record_set "wooster1" do
                    rr_name "wooster.chasm.com"
                    type "CNAME"
                    ttl 300
                    resource_records ["some-other-host"]
                  end
                  aws_route53_record_set "wooster2" do
                    rr_name "wooster.chasm.com"
                    type "A"
                    ttl 3600
                    resource_records ["141.222.1.1"]
                  end
                }
              end
            }.to raise_error(Chef::Exceptions::ValidationFailed, /Duplicate RecordSet found in resource/)
          end

          # normally wouldn't bother with this, but it's best to be safe with the inlined resources.
          it "crashes on a RecordSet with an invalid action" do
            expect_converge {
              aws_route53_hosted_zone zone_name do
                record_sets {
                  aws_route53_record_set "wooster1" do
                    action :invoke
                    rr_name "wooster.example.com"
                    type "CNAME"
                    ttl 300
                  end
                }
              end
            }.to raise_error(Chef::Exceptions::ValidationFailed, /Option action must be equal to one of/)
          end

          it "creates a hosted zone with a RecordSet" do
            expect_recipe {
              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-hostname CNAME" do
                    rr_name "some-host.feegle.com"
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                   resource_record_sets: [{}, {}, sdk_cname_rr]).and be_idempotent
            # the empty {} acts as a wildcard, and all zones have SOA and NS records we want to skip.
          end

          it "creates a hosted zone with a RecordSet with an RR name with a trailing dot" do
            expect_recipe {
              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-host.feegle.com." do
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                   resource_record_sets: [{}, {}, sdk_cname_rr]).and be_idempotent
          end

          # AWS's error for this is "FATAL problem: DomainLabelEmpty encountered", so we help the user out.
          it "crashes with a RecordSet with a mismatched zone name with a trailing dot" do
            expect_converge {
              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-host.wrong-zone.com." do
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to raise_error(Chef::Exceptions::ValidationFailed, /RecordSet name.*does not match parent/)
          end

          it "creates and updates a RecordSet" do
            expected_rr = sdk_cname_rr.merge({ ttl: 1800 })

            expect_recipe {
              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-hostname CNAME" do
                    rr_name "some-host"
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end

              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-hostname CNAME" do
                    rr_name "some-host"
                    type "CNAME"
                    ttl 1800
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                   resource_record_sets: [{}, {}, expected_rr]).and be_idempotent
          end

          it "creates and deletes a RecordSet" do
            expect_recipe {
              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-api-host" do
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end

              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-api-host" do
                    action :destroy
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                   resource_record_sets: [{}, {}]).and be_idempotent
          end

          it "automatically uses the parent zone name in the RecordSet name" do
            expect_recipe {
              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-host" do
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                   resource_record_sets: [{}, {}, sdk_cname_rr]).and be_idempotent
          end

          it "raises the AWS exception when trying to delete a record using mismatched values" do
            @zone_to_delete = zone_name = "raise-aws-exception.com"

            expect_converge {
              aws_route53_hosted_zone zone_name do
                record_sets {
                  aws_route53_record_set "some-hostname CNAME" do
                    rr_name "some-api-host.raise-aws-exception.com"
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.not_to raise_error

            expect_converge {
              aws_route53_hosted_zone zone_name do
                record_sets {
                  aws_route53_record_set "some-hostname CNAME" do
                    action :destroy
                    rr_name "some-api-host.raise-aws-exception.com"
                    type "CNAME"
                    ttl 100
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to raise_error(::Aws::Route53::Errors::InvalidChangeBatch, /Tried to delete.*the values provided do not match the current values/)
          end

          it "uses the resource name as the :rr_name" do
            expect_recipe {
              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-host" do
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                   resource_record_sets: [{}, {}, sdk_cname_rr]).and be_idempotent
          end

          context "inheriting default property values" do
            it "provides zone defaults for RecordSet values" do
              expected_a = {
                name: "another-host.feegle.com.",
                type: "A",
                ttl: 3600,
                resource_records: [{value: "8.8.8.8"}]
              }
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  defaults ttl: 3600, type: "CNAME"
                  record_sets {
                    aws_route53_record_set "some-host" do
                      resource_records ["some-other-host"]
                    end
                    aws_route53_record_set "another-host" do
                      type "A"
                      resource_records ["8.8.8.8"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [{}, {},
                                                      expected_a, sdk_cname_rr]).and be_idempotent
            end

            it "only provides defaults for certain properties" do
              expect_converge {
                aws_route53_hosted_zone "feegle.com" do
                  defaults invalid_default: 42
                  record_sets {
                    aws_route53_record_set "some-host" do
                      resource_records ["some-other-host"]
                    end
                    aws_route53_record_set "another-host" do
                      type "A"
                      resource_records ["8.8.8.8"]
                    end
                  }
                end
              }.to raise_error(Chef::Exceptions::ValidationFailed, /'defaults' keys may be any of/)
            end

            it "checks for requiredness" do
              expect_converge {
                aws_route53_hosted_zone "feegle.com" do
                  defaults ttl: 3600
                  record_sets {
                    aws_route53_record_set "some-host" do
                      resource_records ["some-other-host"]
                    end
                  }
                end
              }.to raise_error(Chef::Exceptions::ValidationFailed, /required/i)
            end
          end

          context "individual RR types" do
            let(:expected) {{
              cname: {
                name: "cname-host.feegle.com.",
                type: "CNAME",
                ttl: 1800,
                resource_records: [{ value: "8.8.8.8" }],
              },
              a: {
                name: "a-host.feegle.com.",
                type: "A",
                ttl: 1800,
                resource_records: [{ value: "141.222.1.1"}, { value: "8.8.8.8" }],
              },
              aaaa: {
                name: "aaaa-host.feegle.com.",
                type: "AAAA",
                ttl: 1800,
                resource_records: [{ value: "2607:f8b0:4010:801::1001"},
                                   { value: "2607:f8b9:4010:801::1001" }],
              },
              mx: {
                name: "mx-host.feegle.com.",
                type: "MX",
                ttl: 1800,
                # AWS does *not* append a dot to these.
                resource_records: [{ value: "10 mail1.example.com"}, { value: "15 mail2.example.com."}],
              },
              txt: {
                name: "txt-host.feegle.com.",
                type: "TXT",
                resource_records: [{ value: '"Very Important Data"' },
                                   { value: '"Even More Important Data"' }],
              },
              srv: {
                name: "srv-host.feegle.com.",
                type: "SRV",
                resource_records: [{ value: "10 50 8889 chef-server.example.com" },
                                   { value: "20 70 80 narf.net" }],
              },
              soa: {
                name: "feegle.com.",
                type: "SOA",
                resource_records: [{ value: "ns-1641.awsdns-13.co.uk. awsdns-hostmaster.amazon.com. 2 7200 900 1209600 86400"}],
              },
              ns: {
                name: "feegle.com.",
                type: "NS",
                resource_records: [{ value: "ns1.amazon.com." },
                                   { value: "ns2.amazon.org." }],
              },
            }}

            it "handles CNAME records" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "CNAME-host" do
                      type "CNAME"
                      ttl 1800
                      resource_records ["8.8.8.8"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:cname] ]).and be_idempotent

              expect_converge {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "CNAME-host" do
                      type "CNAME"
                      ttl 1800
                      resource_records ["141.222.1.1", "8.8.8.8"]
                    end
                  }
                end
              }.to raise_error(Chef::Exceptions::ValidationFailed, /CNAME records.*have a single value/)
            end

            it "handles A records" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "A-host" do
                      type "A"
                      ttl 1800
                      resource_records ["141.222.1.1", "8.8.8.8"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:a] ]).and be_idempotent

              expect_converge {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "A-host" do
                      type "A"
                      ttl 1800
                      resource_records ["hostnames-dont-go-here.com", "8.8.8.8"]
                    end
                  }
                end
              }.to raise_error(Chef::Exceptions::ValidationFailed, /A records are of the form/)
            end

            # we don't validate IPv6 addresses, because they are complex.
            it "handles AAAA records" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "AAAA-host" do
                      type "AAAA"
                      ttl 1800
                      resource_records ["2607:f8b0:4010:801::1001", "2607:f8b9:4010:801::1001"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:aaaa] ]).and be_idempotent
            end

            it "handles MX records" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "MX-host" do
                      type "MX"
                      ttl 1800
                      resource_records ["10 mail1.example.com", "15 mail2.example.com."]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:mx] ]).and be_idempotent
              expect_converge {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "MX-host" do
                      type "MX"
                      ttl 1800
                      resource_records ["10mail1.example.com", "mail2.example.com."]
                    end
                  }
                end
              }.to raise_error(Chef::Exceptions::ValidationFailed, /MX records must have a priority and mail server/)
            end

            it "handles SOA records" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "SOA-host" do
                      rr_name "feegle.com."
                      type "SOA"
                      ttl 300
                      resource_records ["ns-1641.awsdns-13.co.uk. awsdns-hostmaster.amazon.com. 2 7200 900 1209600 86400"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, expected[:soa] ]).and be_idempotent
            end

            it "handles NS records" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "NS-host" do
                      rr_name "feegle.com."
                      type "NS"
                      ttl 300
                      resource_records %w[ns1.amazon.com. ns2.amazon.org.]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ expected[:ns], {} ]).and be_idempotent
            end

            # we don't validate TXT values:
            # http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ResourceRecordTypes.html#TXTFormat
            it "handles TXT records" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "TXT-host" do
                      type "TXT"
                      ttl 300
                      resource_records %w["Very\ Important\ Data" "Even\ More\ Important\ Data"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:txt] ]).and be_idempotent
            end

            it "handles SRV records" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "SRV-host" do
                      type "SRV"
                      ttl 300
                      resource_records ["10 50 8889 chef-server.example.com", "20 70 80 narf.net"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:srv] ]).and be_idempotent

              expect_converge {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "SRV-host" do
                      type "SRV"
                      ttl 300
                      resource_records ["1050 8889 chef-server.example.com", "narf.net"]
                    end
                  }
                end
              }.to raise_error(Chef::Exceptions::ValidationFailed, /SRV.*priority, weight, port, and hostname/)
            end
          end  # end RR types
        end
      end
    end
  end
end

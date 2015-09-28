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

          it "creates and updates a RecordSet" do
            expected_rr = sdk_cname_rr.merge({ ttl: 1800 })

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

              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-hostname CNAME" do
                    rr_name "some-host.feegle.com"
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
                  aws_route53_record_set "some-hostname CNAME" do
                    rr_name "some-api-host.feegle.com"
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end

              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-hostname CNAME" do
                    action :destroy
                    rr_name "some-api-host.feegle.com"
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                   resource_record_sets: [{}, {}]).and be_idempotent
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
            }.to raise_error(Aws::Route53::Errors::InvalidChangeBatch, /Tried to delete.*the values provided do not match the current values/)
          end

          it "uses the resource name as the :rr_name" do
            expect_recipe {
              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-host.feegle.com" do
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                   resource_record_sets: [{}, {}, sdk_cname_rr]).and be_idempotent
          end

          it "applies the :rr_name validations to :name" do
            @zone_to_delete = "feegle.com"

            expect_converge {
              aws_route53_hosted_zone "feegle.com" do
                record_sets {
                  aws_route53_record_set "some-host.feegle.com." do
                    type "CNAME"
                    ttl 3600
                    resource_records ["some-other-host"]
                  end
                }
              end
            }.to raise_error(Chef::Exceptions::ValidationFailed, /Option rr_name.*cannot end with a dot/)
          end

          context "individual RR types" do
            let(:expected) {{
              cname: {
                name: "cname-host.feegle.com.",
                type: "CNAME",
                ttl: 1800,
                resource_records: [{ value: "141.222.1.1"}, { value: "8.8.8.8" }],
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
            }}

            it "handles an A record" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "A-host.feegle.com" do
                      type "A"
                      ttl 1800
                      resource_records ["141.222.1.1", "8.8.8.8"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:a] ]).and be_idempotent
            end
            it "handles an AAAA record" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "AAAA-host.feegle.com" do
                      type "AAAA"
                      ttl 1800
                      resource_records ["2607:f8b0:4010:801::1001", "2607:f8b9:4010:801::1001"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:aaaa] ]).and be_idempotent
            end
            it "handles an MX record" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "MX-host.feegle.com" do
                      type "MX"
                      ttl 1800
                      resource_records ["10 mail1.example.com", "15 mail2.example.com."]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:mx] ]).and be_idempotent
            end
            it "handles an TXT record" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "TXT-host.feegle.com" do
                      type "TXT"
                      ttl 300
                      resource_records %w["Very\ Important\ Data" "Even\ More\ Important\ Data"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:txt] ]).and be_idempotent
            end
            it "handles an SRV record" do
              expect_recipe {
                aws_route53_hosted_zone "feegle.com" do
                  record_sets {
                    aws_route53_record_set "SRV-host.feegle.com" do
                      type "SRV"
                      ttl 300
                      resource_records ["10 50 8889 chef-server.example.com", "20 70 80 narf.net"]
                    end
                  }
                end
              }.to create_an_aws_route53_hosted_zone("feegle.com",
                                                     resource_record_sets: [ {}, {}, expected[:srv] ]).and be_idempotent
            end
          end  # end RR types
        end

        it "handles multiple actions gracefully"
      end
    end
  end
end

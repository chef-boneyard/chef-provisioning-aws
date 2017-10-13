#
# Copyright:: Copyright (c) 2015 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class ::Aws::Route53::Types::ResourceRecordSet
  # removing AWS's trailing dots may not be the best thing, but otherwise our job gets much harder.
  def aws_key
    "#{name.sub(/\.$/, '')}"
  end

  # the API doesn't seem to provide any facility to convert these types into the data structures used by the
  # API; see http://redirx.me/?t3za for the RecordSet type specifically.
  def to_change_struct
    {
      name: name,
      type: type,
      ttl: ttl,
      resource_records: resource_records.map {|r| {:value => r.value}},
    }
  end
end

class Chef::Resource::AwsRoute53RecordSet < Chef::Provisioning::AWSDriver::SuperLWRP

  actions :create, :destroy
  default_action :create

  resource_name :aws_route53_record_set
  attribute :aws_route53_zone_id, kind_of: String, required: true

  attribute :rr_name, required: true

  attribute :type, equal_to: %w(SOA A TXT NS CNAME MX PTR SRV SPF AAAA), required: true

  attribute :ttl, kind_of: Fixnum, required: true

  attribute :resource_records, kind_of: Array, required: true

  # this gets set internally and is not intended for DSL use in recipes.
  attribute :aws_route53_zone_name, kind_of: String, required: true,
                                    is: lambda { |zone_name| validate_zone_name!(rr_name, zone_name) }

  attribute :aws_route53_hosted_zone, required: true

  def initialize(name, *args)
    self.rr_name(name) unless @rr_name
    super(name, *args)
  end

  def validate_rr_type!(type, rr_list)
    case type
    # we'll check for integers, but leave the user responsible for valid DNS names.
    when "A"
      rr_list.all? { |v| v =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ } ||
          raise(::Chef::Exceptions::ValidationFailed,
                "A records are of the form '141.2.25.3'")
    when "MX"
      rr_list.all? { |v| v =~ /^\d+\s+[^ ]+/} ||
          raise(::Chef::Exceptions::ValidationFailed,
                "MX records must have a priority and mail server, of the form '15 mail.example.com.'")
    when "SRV"
      rr_list.all? { |v| v =~ /^\d+\s+\d+\s+\d+\s+[^ ]+$/ } ||
          raise(::Chef::Exceptions::ValidationFailed,
                "SRV records must have a priority, weight, port, and hostname, of the form '15 10 25 service.example.com.'")
    when "CNAME"
      rr_list.size == 1 ||
                raise(::Chef::Exceptions::ValidationFailed,
                      "CNAME records may only have a single value (a hostname).")


    when "SOA", "NS", "TXT", "PTR", "AAAA", "SPF"
      true
    else
      raise ArgumentError, "Argument '#{type}' must be one of #{%w(SOA NS A MX SRV CNAME TXT PTR AAAA SPF)}"
    end
  end

  def validate_zone_name!(rr_name, zone_name)
    if rr_name.end_with?('.') && rr_name !~ /#{zone_name}\.$/
      raise(::Chef::Exceptions::ValidationFailed, "RecordSet name #{rr_name} does not match parent HostedZone name #{zone_name}.")
    end
    true
  end

  # because these resources can't actually converge themselves, we have to trigger the validations.
  def validate!
    [:rr_name, :type, :ttl, :resource_records, :aws_route53_zone_name].each { |f| self.send(f) }

    # this was in an :is validator, but didn't play well with inheriting default values.
    validate_rr_type!(type, resource_records)
  end

  def aws_key
    "#{fqdn}"
  end

  def fqdn
    if rr_name !~ /#{aws_route53_zone_name}\.?$/
      "#{rr_name}.#{aws_route53_zone_name}"
    else
      rr_name
    end
  end

  def to_aws_struct
    {
      name: fqdn,
      type: type,
      ttl: ttl,
      resource_records: resource_records.map { |rr| { value: rr } },
    }
  end

  def to_aws_change_struct(aws_action)
    # there are more elements which are optional, notably 'weight' and 'region': see the API doc at
    # http://redirx.me/?t3zo
    {
      action: aws_action,
      resource_record_set: self.to_aws_struct
    }
  end

  def self.verify_unique!(record_sets)
    seen = {}

    record_sets.each do |rs|
      key = rs.aws_key
      if seen.has_key?(key)
        raise Chef::Exceptions::ValidationFailed.new("Duplicate RecordSet found in resource: [#{key}]")
      else
        seen[key] = 1
      end
    end

    # TODO: be helpful and print out all duplicates, not just the first.

    true
  end
end

class Chef::Provider::AwsRoute53RecordSet < Chef::Provider::LWRPBase
  provides :aws_route53_record_set

  # to make RR changes in transactional batches, it has to be done in the parent resource.
  action :create do
  end

  action :destroy do
  end
end

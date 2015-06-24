class Aws::Route53::Types::ResourceRecordSet
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

  # if you add the trailing dot, AWS returns "FATAL problem: DomainLabelEmpty encountered," so we'll stop that
  # ourselves.
  attribute :rr_name, required: true, callbacks: { "cannot end with a dot" => lambda { |n| n !~ /\.$/ }}
  attribute :type, equal_to: %w(SOA A TXT NS CNAME MX PTR SRV SPF AAAA), required: true
  attribute :ttl, kind_of: Fixnum, required: true

  attribute :resource_records, kind_of: Array, required: true, is: lambda { |rr_list| validate_rr_type(type, rr_list) }

  def initialize(name, *args)
    self.rr_name(name) unless @rr_name
    super(name, *args)
  end

  def validate_rr_type(type, rr_list)
    case type
    # we'll check for integers, but leave the user responsible for valid DNS names.
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

    when "SOA", "A", "TXT", "NS", "PTR", "AAAA"
      true
    else
      raise ArgumentError, "Argument '#{type}' must be one of #{%w(SOA A TXT NS CNAME MX PTR SPF AAAA)}"
    end
  end

  # because these resources can't actually converge themselves, we have to trigger the validations.
  def validate!
    [:rr_name, :type, :ttl, :resource_records].each { |f| self.send(f) }
  end

  def aws_key
    "#{rr_name}"
  end

  def to_aws_struct
    {
      name: rr_name,
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

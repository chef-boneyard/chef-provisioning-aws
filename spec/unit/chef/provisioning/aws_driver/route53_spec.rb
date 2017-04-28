require 'chef/provisioning/aws_driver/driver'

describe ::Aws::Route53::Types::ResourceRecordSet do
  it "returns the correct RecordSet unique key" 
  it "returns the correct AWS change struct"
end

describe Chef::Resource::AwsRoute53RecordSet do

  let(:resource_name) { "test_resource" }
  let(:zone_name) { "blerf.net" }
  let(:resource) {
    r = Chef::Resource::AwsRoute53RecordSet.new(resource_name)
    r.aws_route53_zone_name(zone_name)
    r
  }

  it "returns the correct RecordSet unique key" do
    expect(resource.aws_key).to eq("#{resource_name}.#{zone_name}")
    resource.rr_name("new-name")
    expect(resource.aws_key).to eq("new-name.#{zone_name}")
  end

  it "returns the correct AWS change struct" do
    resource.rr_name("foo")
    resource.ttl(900)
    resource.type("A")
    resource.resource_records(["141.222.1.1", "8.8.8.8"])

    expect(resource.to_aws_struct).to eq({ :name=>"foo.blerf.net",
                                           :type=>"A",
                                           :ttl=>900, 
                                           :resource_records=>[{:value=>"141.222.1.1"}, {:value=>"8.8.8.8"}]
                                           })
  end

  context "#validate_rr_type" do
    it "validates MX values" do
      correct = 2.times.map { [rand(10000), rand(36**40).to_s(36)].join(" ") }
      expect(resource.validate_rr_type!("MX", correct)).to be_truthy

      incorrect = ["string content doesn't matter without a number"]
      expect { resource.validate_rr_type!("MX", incorrect) }.to raise_error(Chef::Exceptions::ValidationFailed,
                                                                            /MX.*priority and mail server/)
    end

    it "validates SRV values" do
      correct = 2.times.map { [rand(10000), rand(10000), rand(10000), rand(36**40).to_s(36)].join(" ") }
      expect(resource.validate_rr_type!("MX", correct)).to be_truthy

      incorrect = ["string content doesn't matter without a number"]
      expect { resource.validate_rr_type!("SRV", incorrect) }.to raise_error(Chef::Exceptions::ValidationFailed,
                                                                             /SRV.*priority, weight, port, and hostname/)
    end

    it "validates CNAME values" do
      correct = ["foo"]
      expect(resource.validate_rr_type!("CNAME", correct)).to be_truthy

      incorrect = ["foo1", "foo2"]
      expect { resource.validate_rr_type!("CNAME", incorrect) }.to raise_error(Chef::Exceptions::ValidationFailed,
                                                                               /CNAME records may only have a single value/)
    end

    it "validates A values" do
      correct = ["141.222.1.1", "8.8.8.8"]
      expect(resource.validate_rr_type!("A", correct)).to be_truthy

      incorrect = ["141.222.1.500", "8.8.8.8x"]
      expect { resource.validate_rr_type!("A", incorrect) }.to raise_error(Chef::Exceptions::ValidationFailed,
                                                                           /A records are of the form/)
    end

    it "quietly accepts the remaining RR types" do
      %w(TXT PTR AAAA SPF).each do |type|
        expect(resource.validate_rr_type!(type, "We're not validating anything on type '#{type}'.")).to be_truthy
      end

      ["SOA", "NS", nil].each do |invalid_type|
        expect { resource.validate_rr_type!("not a valid RR type", invalid_type) }.to raise_error(ArgumentError)
      end
    end
  end

  context "#fqdn" do
    it "generates correct FQDNs" do
      zone_name = "23skidoo.com"
      hostname = "fnord"

      resource.aws_route53_zone_name(zone_name)
      expect(resource.fqdn).to eq("#{resource_name}.#{zone_name}")

      fq_resource = Chef::Resource::AwsRoute53RecordSet.new("#{hostname}.#{zone_name}")
      fq_resource.aws_route53_zone_name(zone_name)
      expect(fq_resource.fqdn).to eq("#{hostname}.#{zone_name}")

      fq_resource = Chef::Resource::AwsRoute53RecordSet.new("#{hostname}.#{zone_name}.")
      fq_resource.aws_route53_zone_name(zone_name)
      expect(fq_resource.fqdn).to eq("#{hostname}.#{zone_name}.")
    end
  end
end

describe Chef::Provider::AwsRoute53HostedZone do
end
require 'chef/provisioning/aws_driver/driver'

describe Aws::Route53::Types::ResourceRecordSet do
  it "returns the correct RecordSet unique key" 
  it "returns the correct AWS change struct"
end

describe Chef::Resource::AwsRoute53RecordSet do

  let(:resource_name) { "test_resource" }
  let(:resource) { Chef::Resource::AwsRoute53RecordSet.new(resource_name) }

  it "returns the correct RecordSet unique key" do
    expect(resource.aws_key).to eq(resource_name)
    resource.rr_name("new-name")
    expect(resource.aws_key).to eq("new-name")
  end

  it "returns the correct AWS change struct" do
    resource.rr_name("foo")
    resource.ttl(900)
    resource.type("A")
    resource.resource_records(["141.222.1.1", "8.8.8.8"])

    expect(resource.to_aws_struct).to eq({ :name=>"foo",
                                           :type=>"A",
                                           :ttl=>900, 
                                           :resource_records=>[{:value=>"141.222.1.1"}, {:value=>"8.8.8.8"}]
                                           })
  end

  context "#validate_rr_type" do
    it "validates MX values" do
      correct = 2.times.map { [rand(10000), rand(36**40).to_s(36)].join(" ") }
      expect(resource.validate_rr_type("MX", correct)).to be_truthy

      incorrect = ["string content doesn't matter without a number"]
      expect { resource.validate_rr_type("MX", incorrect) }.to raise_error(Chef::Exceptions::ValidationFailed,
                                                                           /MX.*priority and mail server/)
    end

    it "validates SRV values" do
      correct = 2.times.map { [rand(10000), rand(10000), rand(10000), rand(36**40).to_s(36)].join(" ") }
      expect(resource.validate_rr_type("MX", correct)).to be_truthy

      incorrect = ["string content doesn't matter without a number"]
      expect { resource.validate_rr_type("SRV", incorrect) }.to raise_error(Chef::Exceptions::ValidationFailed,
                                                                            /SRV.*priority, weight, port, and hostname/)
    end

    it "validates CNAME values" do
      correct = ["foo"]
      expect(resource.validate_rr_type("CNAME", correct)).to be_truthy

      incorrect = ["foo1", "foo2"]
      expect { resource.validate_rr_type("CNAME", incorrect) }.to raise_error(Chef::Exceptions::ValidationFailed,
                                                                            /CNAME records may only have a single value/)
    end

    it "only accepts the remaining RR types" do
      %w(SOA A TXT NS PTR AAAA).each do |type|
        expect(resource.validate_rr_type(type, "We're not validating anything on these types.")).to be_truthy
      end

      expect { resource.validate_rr_type("not a valid RR type", nil) }.to raise_error(ArgumentError)
    end
  end
end

describe Chef::Provider::AwsRoute53HostedZone do
end
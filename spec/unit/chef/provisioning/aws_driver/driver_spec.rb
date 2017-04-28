require 'chef/provisioning/aws_driver/driver'
require 'chef/provisioning/aws_driver/credentials2'

describe Chef::Provisioning::AWSDriver::Driver do

  let(:driver) { Chef::Provisioning::AWSDriver::Driver.new("aws::us-east-1", {}) }
  let(:aws_credentials) { double("credentials", :default => {
    aws_access_key_id: "id",
    aws_secret_access_key: "secret"
  })}
  let(:credentials2) { double("credentials2", :get_credentials => {})}

  before do
    expect_any_instance_of(Chef::Provisioning::AWSDriver::Driver).to receive(:aws_credentials).and_return(aws_credentials)
    expect(Aws.config).to receive(:update) do |h|
      expect(h).to include({
        access_key_id:     "id",
        secret_access_key: "secret",
        region:            "us-east-1"
      })
    end
    expect(Chef::Provisioning::AWSDriver::Credentials2).to receive(:new).and_return(credentials2)
  end

  describe "#determine_remote_host" do
    let(:machine_spec) { double("machine_spec", :reference => reference, :name => 'name') }
    let(:instance) { double("instance", :private_ip_address => 'private', :dns_name => 'dns', :public_ip_address => 'public') }

    context "when 'use_private_ip_for_ssh' is specified in the machine_spec.reference" do
      let(:reference) { { 'use_private_ip_for_ssh' => true } }
      it "returns the private ip" do
        expect(driver.determine_remote_host(machine_spec, instance)).to eq('private')
        expect(reference).to eq( {'transport_address_location' => :private_ip} )
      end
    end

    context "when 'transport_address_location' is set to :private_ip" do
      let(:reference) { { 'transport_address_location' => :private_ip } }
      it "returns the private ip" do
        expect(driver.determine_remote_host(machine_spec, instance)).to eq('private')
      end
    end

    context "when 'transport_address_location' is set to :dns" do
      let(:reference) { { 'transport_address_location' => :dns } }
      it "returns the dns name" do
        expect(driver.determine_remote_host(machine_spec, instance)).to eq('dns')
      end
    end

    context "when 'transport_address_location' is set to :public_ip" do
      let(:reference) { { 'transport_address_location' => :public_ip } }
      it "returns the public ip" do
        expect(driver.determine_remote_host(machine_spec, instance)).to eq('public')
      end
    end

    context "when machine_spec.reference does not specify the transport type" do
      let(:reference) { Hash.new }

      context "when the machine does not have a public_ip_address" do
        let(:instance) { double("instance", :private_ip_address => 'private', :public_ip_address => nil) }

        it "returns the private ip" do
          expect(driver.determine_remote_host(machine_spec, instance)).to eq('private')
        end
      end

      context "when the machine has a public_ip_address" do
        let(:instance) { double("instance", :private_ip_address => 'private', :public_ip_address => 'public') }

        it "returns the public ip" do
          expect(driver.determine_remote_host(machine_spec, instance)).to eq('public')
        end
      end

      context "when the machine does not have a public_ip_address or private_ip_address" do
        let(:instance) { double("instance", :private_ip_address => nil, :public_ip_address => nil, :id => 'id') }

        it "raises an error" do
          expect {driver.determine_remote_host(machine_spec, instance)}.to raise_error("Server #{instance.id} has no private or public IP address!")
        end
      end
    end
  end

end

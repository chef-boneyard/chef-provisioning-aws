require "chef/provisioning/aws_driver"

iam = AWS::Core::CredentialProviders::EC2Provider.new

with_driver(
  "aws:IAM:us-east-1",
  aws_credentials: { "IAM" => iam.credentials }
)

machine "iam-machine-1" do
  machine_options bootstrap_options: {
    # subnet_id: 'ref-subnet',
    # security_group_ids: 'ref-sg1',
    # image_id: 'ref-machine_image1',
    # instance_type: 't2.small'
  }
end

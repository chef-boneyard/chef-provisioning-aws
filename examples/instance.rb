require 'chef/provisioning/aws_driver'
with_driver 'aws'

aws_instance 'cdoherty-tf-test' do
  action :terraform

  # only uses :destroy, everything else is `terraform apply`.
  terraform_action :destroy

  # required options.
  ami "ami-cf35f3a4"    # us-east-1 Ubuntu amd64 14.04 EBS HVM
  instance_type "t2.micro"

  # optional...options.
  key_name "cdoherty-chef"
  tags user: "cdoherty", purpose: "Terraform testing", comment: "Go ahead and delete it."

  user_data "wget https://raw.githubusercontent.com/randomcamel/ec2-instance-info/master/instance-info"
end

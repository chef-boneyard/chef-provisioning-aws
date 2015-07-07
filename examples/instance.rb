require 'chef/provisioning/aws_driver'
with_driver 'aws'

aws_instance 'cdoherty-tf-test' do
  action :terraform

  # to communicate "destroy" or whatever.
  terraform_action :do_something

  # required options.
  ami "ami-cf35f3a4"    # us-east-1 Ubuntu amd64 14.04 EBS HVM
  instance_type "t2.micro"

  # optional...options.
  key_name "cdoherty-chef"
  # security_groups ["stephen-demo-global-http"]
  tags user: "cdoherty", purpose: "Terraform testing", comment: "Go ahead and delete it."
end

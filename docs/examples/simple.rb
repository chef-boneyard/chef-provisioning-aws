# Here's a simple example using the driver that will create an ELB, a new EC2
# instance, and an SQS queue in eu-west-1 and then attach the new instance to
# the ELB.
#
# It will also create an SNS topic and SQS queue in us-west-1.

require 'chef/provisioning/aws_driver'

with_driver 'aws'

machine 'bowser' do; action :destroy; end
  machine 'bowser' do
  end

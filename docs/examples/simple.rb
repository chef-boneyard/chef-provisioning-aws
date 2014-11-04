# Here's a simple example using the driver that will create an ELB, a new EC2
# instance, and an SQS queue in eu-west-1 and then attach the new instance to
# the ELB.
#
# It will also create an SNS topic and SQS queue in us-west-1.

require 'chef/provisioning/aws_driver'
with_driver 'aws'

with_data_center 'eu-west-1' do
  aws_sqs_queue "mariopipes"

  machine 'bowser' do
    machine_options :bootstrap_options => {
            :key_name => 'aws_key'
      }
  end

  load_balancer "webapp-elb" do
    load_balancer_options :availability_zones => ['eu-west-1a'],
                          :listeners => [{
                               :port => 80,
                               :protocol => :http,
                               :instance_port => 80,
                               :instance_protocol => :http,
                           }]
    machines ['bowser']
  end
end

with_datacenter 'us-west-1' do
  aws_sqs_queue 'luigipipe'
  aws_sns_topic 'us_west_topic'
end

require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

aws_key_pair 'ref-key-pair-ebs'

with_machine_options :bootstrap_options => { :key_name => 'ref-key-pair-ebs' }

machine 'ref-machine-1'

aws_network_interface 'ref-eni-1' do
  
end

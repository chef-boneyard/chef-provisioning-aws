require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

aws_key_pair 'ref-key-pair-ebs'

with_machine_options :bootstrap_options => { :key_name => 'ref-key-pair-ebs' }

machine 'ref-machine-1'

# create volume
aws_ebs_volume 'ref-volume-ebs' do
  availability_zone 'us-west-2a'
  size 1
end

# attach to machine
aws_ebs_volume 'ref-volume-ebs' do
  machine 'ref-machine-1'
  device '/dev/xvdf'
end

# reattach to different device
aws_ebs_volume 'ref-volume-ebs' do
  device '/dev/xvdg'
end

# detach
aws_ebs_volume 'ref-volume-ebs' do
  machine false
end

# delete volume
aws_ebs_volume 'ref-volume-ebs' do
  action :destroy
end

machine 'ref-machine-1' do
  action :destroy
end

aws_key_pair 'ref-key-pair-ebs' do
  action :destroy
end

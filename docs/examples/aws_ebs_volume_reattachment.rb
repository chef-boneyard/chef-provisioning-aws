require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

aws_key_pair 'ref-key-pair-ebs'

ref_machine1 = machine 'ref-machine-1'

# create and attach to initial machine
aws_ebs_volume 'ref-volume' do
  action [:create, :attach]
  machine ref_machine1.name
  device '/dev/xvdf'
  availability_zone 'us-west-2a'
  size 1
end

ref_machine2 = machine 'ref-machine-2'

# attach to new machine
aws_ebs_volume 'ref-volume' do
  action :attach
  machine ref_machine2.name
  device '/dev/xvdf'
end

# attach to new device
aws_ebs_volume 'ref-volume' do
  action :attach
  machine ref_machine2.name
  device '/dev/xvdg'
end

# detach from machine without setting device or machine
aws_ebs_volume 'ref-volume' do
  action :detach
end

aws_ebs_volume 'ref-volume' do
  action :delete
end

machine_batch do
  machines 'ref-machine-1', 'ref-machine-2'
  action :destroy
end

aws_key_pair 'ref-key-pair-ebs' do
  action :delete
end

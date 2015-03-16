require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

key = aws_key_pair 'ref-key-pair-ebs'
key.run_action(:create)

ref_machine1 = machine 'ref-machine-1'
ref_machine1.run_action(:converge)

# create and attach to initial machine
ebs_volume = aws_ebs_volume 'ref-volume' do
  action :nothing
  machine 'ref-machine-1'
  device '/dev/xvdf'
  availability_zone 'us-west-2a'
  size 1
end

ebs_volume.run_action(:create)
ebs_volume.run_action(:attach)

ref_machine2 = machine 'ref-machine-2'
ref_machine2.run_action(:converge)

# attach to new machine
ebs_volume.machine('ref-machine-2')
ebs_volume.run_action(:attach)

# attach to new device
ebs_volume.device('/dev/xvdg')
ebs_volume.run_action(:attach)

# detach from machine without setting device
ebs_volume.device(nil)
ebs_volume.run_action(:detach)

ebs_volume.run_action(:delete)

machine_batch do
  machines 'ref-machine-1', 'ref-machine-2'
  action :destroy
end

aws_key_pair 'ref-key-pair-ebs' do
  action :delete
end


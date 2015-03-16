require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

key = aws_key_pair 'ref-key-pair-ebs'
key.run_action(:create)

ref_machine1 = machine 'ref-machine-1'
ref_machine1.run_action(:converge)

ebs_volume = aws_ebs_volume 'ref-volume-ebs' do
  action :nothing
  machine ref_machine1.name
  device '/dev/xvdf'
  availability_zone 'us-west-2a'
  size 1
end

ebs_volume.run_action(:create)
ebs_volume.run_action(:create) # up to date
ebs_volume.run_action(:attach)
ebs_volume.run_action(:attach) # up to date
ebs_volume.run_action(:detach)
ebs_volume.run_action(:detach) # up to date
ebs_volume.run_action(:delete)
ebs_volume.run_action(:delete) # up to date

# TODO test elsewhere
# aws_ebs_volume 'ebs-12345678' do
#   action :attach
#   machine 'ref-machine2'
#   device '/dev/xvdf'
# end

machine ref_machine1.name do
  action :destroy
end

aws_key_pair 'ref-key-pair-ebs' do
  action :delete
end


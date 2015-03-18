require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

aws_key_pair 'ref-key-pair-ebs'

ref_machine1 = machine 'ref-machine-1'

aws_ebs_volume 'ref-volume-ebs' do
  availability_zone 'us-west-2a'
  size 1
end

aws_ebs_volume 'ref-volume-ebs' do
  availability_zone 'us-west-2a'
  size 1
end

aws_ebs_volume 'ref-volume-ebs' do
  action :attach
  machine ref_machine1.name
  device '/dev/xvdf'
end

aws_ebs_volume 'ref-volume-ebs' do
  action :attach
  machine ref_machine1.name
  device '/dev/xvdf'
end

aws_ebs_volume 'ref-volume-ebs' do
  action :detach
end

aws_ebs_volume 'ref-volume-ebs' do
  action :detach
end

aws_ebs_volume 'ref-volume-ebs' do
  action :delete
end

aws_ebs_volume 'ref-volume-ebs' do
  action :delete
end

machine ref_machine1.name do
  action :destroy
end

aws_key_pair 'ref-key-pair-ebs' do
  action :delete
end

# Changelog

## 0.2.2 (4/10/2015)

- Un-pinning chef-provisioning from github master - it is no longer 0.9 there.  This is to fix failing
  ChefDK builds until ChefDK 0.5.0 is released and the 1.0 provisioning branches are used.  No
  active development should be done on this 0.2 branch.

## 0.2.1 (1/27/2015)

- Fix issue with not waiting for ssh transport to be up (@afiune)
- Don't require lb_options when defaults will do (@bbbco)

## 0.2 (1/27/2015)

- `aws_subnet` support (@meekmichael)
- `aws_s3_bucket` static website support (@jdmundrawala)
- `machine_image` support (@miguelcnf)
- Make `machine_batch` parallelize requests (@lynchc)
- Support profile name and region in driver URL (aws:profilename:us-east-1)
- Make `machine_execute` and `machine_file` work (implement `connect_to_machine`) (@miguelcnf)

- Make `ssh_username` work again
- Fix issues waiting for pending machines or waiting for machines on the second run

## 0.1.3

## 0.1.2

## 0.1.1

## 0.1 (9/18/2014)

- Initial revision.  Use at own risk :)

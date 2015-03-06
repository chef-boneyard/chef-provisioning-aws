# Changelog

## 0.4.0 (3/4/2015)

- Add `driver` and `with_driver` support to AWS resources, remove `region` as a resource attribute and remove `with_data_center` (@jkeiser)
- `load_balancer` can now be created without any associated machines (@christinedraper)
- Set region from credentials if not specified in driver url (@christinedraper)
- Added support for scheme and subnet attributes in the `load_balancer` resource (@erikvanbrakel & @tyler-ball)
- Renamed `load_balancer_options` security_group_id to security_group_ids and security_group_name to security_group_names.  These now accept an array of Strings. (@erikvanbrakel & @tyler-ball)


## 0.3 (2/25/2015)

- WinRM support! (@erikvanbrakel)
- Make load balancers much more updateable (@tyler-ball)
- Load balancer crash fixes (@lynchc)
- Fix machine_batch to pick an image when image is not specified (@jkeiser)
- Delete snapshot when deleting image (@christinedraper)
- Support bootstrap_options => { image_id: 'ami-234243225' } (@christinedraper)
- Support load_balancers and desired_capacity in aws_auto_scaling_group (@christinedraper)
- Get aws_security_group :delete working (@christinedraper)
- Fixes for merged machine_options (add_machine_options, etc.) (@schisamo @jkeiser)

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

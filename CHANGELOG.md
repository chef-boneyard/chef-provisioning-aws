# Changelog

## 1.3.1 (8/5/2015)

- Exponentially backoff when trying to tag resources ([#263][], [@tyler-ball][])
- Only apply default `user_data` in Windows if it has not been set by the user ([#270][], [@brumschlag][])
- Fix load balancer SSL certificates ([#275][], [@stevendanna][])

## 1.3.0 (7/17/2015)

- Adding support for Elasticache ([#212][])
- Adding support for Network ACLs ([#241][])
- Adding support for ELB attributes which enables cross-zone load balancing ([#199][])
- Fixing machine destroy when using EC2 classic ([#209][])
- Use the `ubuntu_ami` gem to query Ubuntu AMIs instead of hardcoding them ([#197][])
- Fixing security group rule comparison when a protocol is specified ([#237][])
- Wait for VPC to be created before attempting to tag it ([#245][])
- Adding support for Chef 12.4.x ([#250][])
- Adding a new RSPEC matcher which does not perform any CRUD operations, only validation ([#248][])
- Documentation updates ([#234][], [#236][], [#239][])

## 1.2.1 (5/27/2015)

- I didn't actually fix [#158][] and [#204][] - fixing and adding test coverage

## 1.2.0 (5/27/2015)

- Security groups can be referenced by group-name, don't need a data bag entry ([#194][])
- Added support for tags across almost all resources.  See the README for examples ([#190][])
- Updated `aws_route_table` with the ability to ignore routes with regex matching.  This supports AWS performing automatic route switching for HA purposes without chef-provisioning interfering with that logic. ([@dblessing][], [#172][])
- Updated `aws_route_table` to propogate routes from provided virtual gateways.  See the comments in the resource for specifics.  ([@dblessing][], [#151][])
- Updated the `docs/examples/ref_*` examples to execute correctly and fixed broken integration tests ([@tyler-ball][])

## 1.1.1 (4/28/2015)

- Fixed bug where refering to the same `machine` an an `aws_instance` would would raise a RuntimeError ([@patrick-wright][], [@tyler-ball][] [#191][])
- Added new `destroy_an_aws_object` matcher for use in integration tests ([@patrick-wright][] [#186][])
- Add ability to turn off source/dest check ([@dblessing][])

## 1.1.0 (4/16/2015)

- Added `aws_network_interface` resource ([@patrick-wright][] [#167][])
- Added integration tests which automatically destroy AWS resources after use ([@jkeiser][] [#152][])
- Added `action :purge` support on aws resources, will delete all dependent resources in addition to the current resource ([@jkeiser][] [@tyler-ball][] [#152][] [#187][])
  - EG, `action :purge` on the VPC will delete the subnet, machines, etc.
- Update `docs/examples` to be consistent with current codebase ([@msonnabaum][] [#181][] [#179][])
- Added version constraint for aws-sdk to support required features ([@msonnabaum][] [#178][])
- Updated `aws_ebs_volume` `:availability_zone` attribute to only require letter instead of full region and letter ([@patrick-wright][] [#185][])
  - IE, use `availability_zone 'a'` instead of `availability_zone 'us-east-1a'`
- Added AWS Proxy & Session Token Support ([@afiune][] [#177][])

## 1.0.4 (4/7/2015)

- Removed resource cloning again
- Moved chef-zero to a development dependence because it is only used for testing

## 1.0.3 (4/7/2015)

- Unpinning cheffish, using dependency from chef-provisioning

## 1.0.2 (4/6/2015)

- Use released 4.2.0 version of chef-zero instead of pointing towards github

## 1.0.1 (4/6/2015)

- Use released 1.0.0 version of chef-provisioning instead of pointing towards github

## 1.0.0 (4/2/2015)
## 1.0.0.rc.1 (3/31/2015)

- Fix issue with load balancer failing on the second run

## 0.5.0 (3/26/2015)

- Expanded `docs/examples` with many more references
- Refactored the data_bag storage for easier development.  This should not affect existing cookbooks. ([@jkeiser][])
- All resources which reference an `aws_resource` can be referenced by resource name, AWS object or AWS object identifier.  See `docs/examples/attribute_reference.rb` for an example. ([@jkeiser][])
- Existing AWS resources can be 'imported' (have a data bag managed entry created) by specifying their identifier in the resource's aws_id_attribute.  EG,
```ruby
aws_security_group "my_group" do
  security_group_id 'sg-123456'
end
```
([@jkeiser][])
- Updated `aws_vpc` to support an `internet_gateway true/false` flag ([@jkeiser][])
- Updated `aws_security_group` inbound/outbound rules for easier readability.  See `docs/examples/sg_test.rb` for an example. ([@jkeiser][])
- Added new `aws_dhcp_options`, `aws_route_table` resource/provider ([@jkeiser][])
- Added new `aws_ebs_volume` resource/provider ([@patrick-wright][])
- Deprecated `action :delete` across all `aws_*` resources - use `action :destroy` instead.

## 0.4.0 (3/4/2015)

- Add `driver` and `with_driver` support to AWS resources, remove `region` as a resource attribute and remove `with_data_center` ([@jkeiser][])
- `load_balancer` can now be created without any associated machines ([@christinedraper][])
- Set region from credentials if not specified in driver url ([@christinedraper][])
- Added support for scheme and subnet attributes in the `load_balancer` resource ([@erikvanbrakel][] & [@tyler-ball][])
- Renamed `load_balancer_options` security_group_id to security_group_ids and security_group_name to security_group_names.  These now accept an array of Strings. ([@erikvanbrakel][] & [@tyler-ball][])


## 0.3 (2/25/2015)

- WinRM support! ([@erikvanbrakel][])
- Make load balancers much more updateable ([@tyler-ball][])
- Load balancer crash fixes ([@lynchc][])
- Fix machine_batch to pick an image when image is not specified ([@jkeiser][])
- Delete snapshot when deleting image ([@christinedraper][])
- Support bootstrap_options => { image_id: 'ami-234243225' } ([@christinedraper][])
- Support load_balancers and desired_capacity in aws_auto_scaling_group ([@christinedraper][])
- Get aws_security_group :destroy working ([@christinedraper][])
- Fixes for merged machine_options (add_machine_options, etc.) ([@schisamo][] [@jkeiser][])

## 0.2.1 (1/27/2015)

- Fix issue with not waiting for ssh transport to be up ([@afiune][])
- Don't require lb_options when defaults will do ([@bbbco][])

## 0.2 (1/27/2015)

- `aws_subnet` support ([@meekmichael][])
- `aws_s3_bucket` static website support ([@jdmundrawala][])
- `machine_image` support ([@miguelcnf][])
- Make `machine_batch` parallelize requests ([@lynchc][])
- Support profile name and region in driver URL (aws:profilename:us-east-1)
- Make `machine_execute` and `machine_file` work (implement `connect_to_machine`) ([@miguelcnf][])

- Make `ssh_username` work again
- Fix issues waiting for pending machines or waiting for machines on the second run

## 0.1.3

## 0.1.2

## 0.1.1

## 0.1 (9/18/2014)

- Initial revision.  Use at own risk :)

<!--- The following link definition list is generated by PimpMyChangelog --->
[#151]: https://github.com/chef/chef-provisioning-aws/issues/151
[#152]: https://github.com/chef/chef-provisioning-aws/issues/152
[#158]: https://github.com/chef/chef-provisioning-aws/issues/158
[#167]: https://github.com/chef/chef-provisioning-aws/issues/167
[#172]: https://github.com/chef/chef-provisioning-aws/issues/172
[#177]: https://github.com/chef/chef-provisioning-aws/issues/177
[#178]: https://github.com/chef/chef-provisioning-aws/issues/178
[#179]: https://github.com/chef/chef-provisioning-aws/issues/179
[#181]: https://github.com/chef/chef-provisioning-aws/issues/181
[#185]: https://github.com/chef/chef-provisioning-aws/issues/185
[#186]: https://github.com/chef/chef-provisioning-aws/issues/186
[#187]: https://github.com/chef/chef-provisioning-aws/issues/187
[#190]: https://github.com/chef/chef-provisioning-aws/issues/190
[#191]: https://github.com/chef/chef-provisioning-aws/issues/191
[#194]: https://github.com/chef/chef-provisioning-aws/issues/194
[#197]: https://github.com/chef/chef-provisioning-aws/issues/197
[#199]: https://github.com/chef/chef-provisioning-aws/issues/199
[#204]: https://github.com/chef/chef-provisioning-aws/issues/204
[#209]: https://github.com/chef/chef-provisioning-aws/issues/209
[#212]: https://github.com/chef/chef-provisioning-aws/issues/212
[#234]: https://github.com/chef/chef-provisioning-aws/issues/234
[#236]: https://github.com/chef/chef-provisioning-aws/issues/236
[#237]: https://github.com/chef/chef-provisioning-aws/issues/237
[#239]: https://github.com/chef/chef-provisioning-aws/issues/239
[#241]: https://github.com/chef/chef-provisioning-aws/issues/241
[#245]: https://github.com/chef/chef-provisioning-aws/issues/245
[#248]: https://github.com/chef/chef-provisioning-aws/issues/248
[#250]: https://github.com/chef/chef-provisioning-aws/issues/250
[#263]: https://github.com/chef/chef-provisioning-aws/issues/263
[#270]: https://github.com/chef/chef-provisioning-aws/issues/270
[#275]: https://github.com/chef/chef-provisioning-aws/issues/275
[@afiune]: https://github.com/afiune
[@bbbco]: https://github.com/bbbco
[@brumschlag]: https://github.com/brumschlag
[@christinedraper]: https://github.com/christinedraper
[@dblessing]: https://github.com/dblessing
[@erikvanbrakel]: https://github.com/erikvanbrakel
[@jdmundrawala]: https://github.com/jdmundrawala
[@jkeiser]: https://github.com/jkeiser
[@lynchc]: https://github.com/lynchc
[@meekmichael]: https://github.com/meekmichael
[@miguelcnf]: https://github.com/miguelcnf
[@msonnabaum]: https://github.com/msonnabaum
[@patrick-wright]: https://github.com/patrick-wright
[@schisamo]: https://github.com/schisamo
[@stevendanna]: https://github.com/stevendanna
[@tyler-ball]: https://github.com/tyler-ball
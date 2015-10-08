# Change Log

## [1.4.1](https://github.com/chef/chef-provisioning-aws/tree/1.4.1) (2015-09-22)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.4.0...1.4.1)

**Fixed bugs:**

- associate\_public\_ip\_address no longer working [\#338](https://github.com/chef/chef-provisioning-aws/issues/338)
- Invalid BASE64 encoding of user data in 1.4.0 [\#325](https://github.com/chef/chef-provisioning-aws/issues/325)
- Unable to create ec2 instance with multiple IPs [\#322](https://github.com/chef/chef-provisioning-aws/issues/322)
- ERROR: :aws\_instance\_profile bootstrap option expects a hash \(between 1.3.1 and master\) [\#309](https://github.com/chef/chef-provisioning-aws/issues/309)
- Making machine bootstrap\_options backwards compatible to the V1 API [\#339](https://github.com/chef/chef-provisioning-aws/pull/339) ([tyler-ball](https://github.com/tyler-ball))
- Latest tagging refactors depend on chef-provisioning 1.4, updating the gemspec to reflect this [\#335](https://github.com/chef/chef-provisioning-aws/pull/335) ([tyler-ball](https://github.com/tyler-ball))
- V1 SDK automatically accepted ENV\[AWS\_CONFIG\_FILE\] but V2 doesn't, so we need to update to support that [\#334](https://github.com/chef/chef-provisioning-aws/pull/334) ([tyler-ball](https://github.com/tyler-ball))
- removing non-base64 windows user\_data [\#330](https://github.com/chef/chef-provisioning-aws/pull/330) ([hh](https://github.com/hh))
- Converting iam profile from a string to a hash to support v1 to v2 migration, fixes \#309 [\#328](https://github.com/chef/chef-provisioning-aws/pull/328) ([tyler-ball](https://github.com/tyler-ball))
- user\_data needs to be base64 encoded in SDK V2, fixes \#325 [\#327](https://github.com/chef/chef-provisioning-aws/pull/327) ([tyler-ball](https://github.com/tyler-ball))
- Strip key\_path from the bootstrap options [\#295](https://github.com/chef/chef-provisioning-aws/pull/295) ([ryancragun](https://github.com/ryancragun))

**Closed issues:**

- machine :converge\_only ignores chef\_server param when run via chef-zero [\#329](https://github.com/chef/chef-provisioning-aws/issues/329)

## [v1.4.0](https://github.com/chef/chef-provisioning-aws/tree/v1.4.0) (2015-09-16)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.3.1...v1.4.0)

**Implemented enhancements:**

- Update resources to allow route tables with pcx [\#312](https://github.com/chef/chef-provisioning-aws/pull/312) ([joaogbcravo](https://github.com/joaogbcravo))
- Add aws\_vpc\_peering\_connection. [\#305](https://github.com/chef/chef-provisioning-aws/pull/305) ([joaogbcravo](https://github.com/joaogbcravo))
- Adding api V2 for machine create and destroy, fixes \#216 [\#293](https://github.com/chef/chef-provisioning-aws/pull/293) ([tyler-ball](https://github.com/tyler-ball))
- Initial commit of aws\_rds\_subnet\_group resource [\#276](https://github.com/chef/chef-provisioning-aws/pull/276) ([stevendanna](https://github.com/stevendanna))
- Add support for aws\_server\_certificate resource/provider. [\#274](https://github.com/chef/chef-provisioning-aws/pull/274) ([tylercloke](https://github.com/tylercloke))
- Initial commit of aws\_cloudsearch\_domain resource [\#273](https://github.com/chef/chef-provisioning-aws/pull/273) ([stevendanna](https://github.com/stevendanna))
- Initial commit of aws\_rds\_instance resource [\#272](https://github.com/chef/chef-provisioning-aws/pull/272) ([stevendanna](https://github.com/stevendanna))

**Fixed bugs:**

- chef-recipe ArgumentError unknown directive: “\n” [\#298](https://github.com/chef/chef-provisioning-aws/issues/298)
- Provisoner's IAM roles are not used [\#292](https://github.com/chef/chef-provisioning-aws/issues/292)
- Remove dsl\_name deprecation warnings introduced by Chef 12.4.0 [\#288](https://github.com/chef/chef-provisioning-aws/issues/288)
- Add code coverage metrics for chef-provisioning-aws [\#285](https://github.com/chef/chef-provisioning-aws/issues/285)
- Command line is too long. [\#284](https://github.com/chef/chef-provisioning-aws/issues/284)
- Better support for tags [\#281](https://github.com/chef/chef-provisioning-aws/issues/281)
- Intermittent AWS AuthFailure executing aws\_key\_pair [\#268](https://github.com/chef/chef-provisioning-aws/issues/268)
- Can't connect to EC2 instance in VPC with public IP [\#267](https://github.com/chef/chef-provisioning-aws/issues/267)
- AWS::EC2::Errors::InvalidInstanceID::NotFound When creating a `machine`  [\#264](https://github.com/chef/chef-provisioning-aws/issues/264)
- Investigate AWS::EC2::Errors::InvalidVpcID::NotFound [\#251](https://github.com/chef/chef-provisioning-aws/issues/251)
- AWS::EC2::Errors::RequestLimitExceeded: Request limit exceeded - when launching many instances in a batch [\#214](https://github.com/chef/chef-provisioning-aws/issues/214)
- cannot build machine using from\_image in AWS  [\#193](https://github.com/chef/chef-provisioning-aws/issues/193)
- Machines and images report connectable even if they time out [\#122](https://github.com/chef/chef-provisioning-aws/issues/122)
- Allow specifying health check on ELB [\#107](https://github.com/chef/chef-provisioning-aws/issues/107)
- Specified AMI not being used [\#102](https://github.com/chef/chef-provisioning-aws/issues/102)
- bootstrap tagging options [\#21](https://github.com/chef/chef-provisioning-aws/issues/21)
- Ensuring all V2 aws classes are prepended with :: to limit namespace scope [\#323](https://github.com/chef/chef-provisioning-aws/pull/323) ([tyler-ball](https://github.com/tyler-ball))
- Tagging Refactor Part 1, fixes \#281 [\#314](https://github.com/chef/chef-provisioning-aws/pull/314) ([tyler-ball](https://github.com/tyler-ball))
- Update resources to allow route tables with pcx [\#312](https://github.com/chef/chef-provisioning-aws/pull/312) ([joaogbcravo](https://github.com/joaogbcravo))
- Adding provides syntax to all providers to get rid of 12.4.0 chef warnings [\#303](https://github.com/chef/chef-provisioning-aws/pull/303) ([tyler-ball](https://github.com/tyler-ball))
- Renaming actual\_instance because I don't think it provides more information than just instance [\#302](https://github.com/chef/chef-provisioning-aws/pull/302) ([tyler-ball](https://github.com/tyler-ball))
- Adding configurable option for retry\_limit on the AWS SDK, fixes \#214 [\#301](https://github.com/chef/chef-provisioning-aws/pull/301) ([tyler-ball](https://github.com/tyler-ball))
- Add recursive\_delete attribute to a aws\_s3\_bucket [\#300](https://github.com/chef/chef-provisioning-aws/pull/300) ([stevendanna](https://github.com/stevendanna))
- Add recursive\\_delete attribute to a aws\\_s3\\_bucket [\#300](https://github.com/chef/chef-provisioning-aws/pull/300) ([stevendanna](https://github.com/stevendanna))
- Adding api V2 for machine create and destroy, fixes \\#216 [\#293](https://github.com/chef/chef-provisioning-aws/pull/293) ([tyler-ball](https://github.com/tyler-ball))
- Add from\_image support [\#291](https://github.com/chef/chef-provisioning-aws/pull/291) ([Fodoj](https://github.com/Fodoj))
- Update README.md [\#282](https://github.com/chef/chef-provisioning-aws/pull/282) ([larrywright](https://github.com/larrywright))
- Adding retry logic around tagging for resources which don't have a Name tag [\#280](https://github.com/chef/chef-provisioning-aws/pull/280) ([tyler-ball](https://github.com/tyler-ball))
- Replacing use\_private\_ip\_for\_ssh with transport\_address\_location, fixes \#267 [\#269](https://github.com/chef/chef-provisioning-aws/pull/269) ([tyler-ball](https://github.com/tyler-ball))

**Closed issues:**

- Retrieve windows instance passwords via Aws::EC2::Client\#get\_password\_data [\#313](https://github.com/chef/chef-provisioning-aws/issues/313)
- Update `aws-sdk-v1` version [\#307](https://github.com/chef/chef-provisioning-aws/issues/307)
- Introduce the AWS SDK V2 to the code [\#216](https://github.com/chef/chef-provisioning-aws/issues/216)

**Merged pull requests:**

- Make chef a development dependency [\#321](https://github.com/chef/chef-provisioning-aws/pull/321) ([ksubrama](https://github.com/ksubrama))
- Adding a CONTRIBUTING document [\#316](https://github.com/chef/chef-provisioning-aws/pull/316) ([tyler-ball](https://github.com/tyler-ball))
- Generate code coverage with specs. [\#287](https://github.com/chef/chef-provisioning-aws/pull/287) ([randomcamel](https://github.com/randomcamel))
- edit strings for consistency, branding \(AWS\) [\#283](https://github.com/chef/chef-provisioning-aws/pull/283) ([jamescott](https://github.com/jamescott))

## [v1.3.1](https://github.com/chef/chef-provisioning-aws/tree/v1.3.1) (2015-08-05)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.3.0...v1.3.1)

**Fixed bugs:**

- machine\_batch exits with error  - NoMethodError: undefined method `encoding' for nil:NilClass [\#277](https://github.com/chef/chef-provisioning-aws/issues/277)
- AWS Driver does not return credentials with machine\_batch [\#260](https://github.com/chef/chef-provisioning-aws/issues/260)
- Elastic Load Balancers: SSL works on create, but not update [\#258](https://github.com/chef/chef-provisioning-aws/issues/258)
- Error re signing request when running integration tests [\#235](https://github.com/chef/chef-provisioning-aws/issues/235)
- Machine with name that could be instance id is not being destroyed [\#232](https://github.com/chef/chef-provisioning-aws/issues/232)
- running bundle exec rake rspec fails without a valid /etc/chef/client.pem [\#231](https://github.com/chef/chef-provisioning-aws/issues/231)
- Support Network ACLs [\#168](https://github.com/chef/chef-provisioning-aws/issues/168)
- Fix handling of lb server certificates, fixes \#258 [\#275](https://github.com/chef/chef-provisioning-aws/pull/275) ([stevendanna](https://github.com/stevendanna))
- only update bootstrap\_options\[:user\_data\] in windows, if one hasn't been provided [\#270](https://github.com/chef/chef-provisioning-aws/pull/270) ([brumschlag](https://github.com/brumschlag))
- Adding exponential backoff when checking taggable status [\#263](https://github.com/chef/chef-provisioning-aws/pull/263) ([tyler-ball](https://github.com/tyler-ball))
- load balancer example [\#262](https://github.com/chef/chef-provisioning-aws/pull/262) ([avleen](https://github.com/avleen))

**Closed issues:**

- Cannot create security groups when creating an ec2 instance.  [\#271](https://github.com/chef/chef-provisioning-aws/issues/271)
- when an audit-mode recipe is part of the node's specified run\_list, provisioning run stack traces [\#259](https://github.com/chef/chef-provisioning-aws/issues/259)
- aws\_launch\_configuration doesn't respect key\_name [\#255](https://github.com/chef/chef-provisioning-aws/issues/255)
- Ability to tag machines [\#252](https://github.com/chef/chef-provisioning-aws/issues/252)
- bootstrap instances to chef-server [\#246](https://github.com/chef/chef-provisioning-aws/issues/246)
- Can not create load\_balancer with out machines [\#243](https://github.com/chef/chef-provisioning-aws/issues/243)
- Load Balancer Destroy does not work with 'internal' load balancers [\#173](https://github.com/chef/chef-provisioning-aws/issues/173)

**Merged pull requests:**

- Expanding machine\_options documentation [\#265](https://github.com/chef/chef-provisioning-aws/pull/265) ([tyler-ball](https://github.com/tyler-ball))
- Adding documentation for key\_pair on launch configuration, fixes \#255 [\#261](https://github.com/chef/chef-provisioning-aws/pull/261) ([tyler-ball](https://github.com/tyler-ball))
- yard doc first pass on elasticache code [\#233](https://github.com/chef/chef-provisioning-aws/pull/233) ([metadave](https://github.com/metadave))

## [v1.3.0](https://github.com/chef/chef-provisioning-aws/tree/v1.3.0) (2015-07-17)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.2.1...v1.3.0)

**Implemented enhancements:**

- Support for elasticache [\#207](https://github.com/chef/chef-provisioning-aws/issues/207)
- Adding a matcher which doesn't do any CRUD operations [\#248](https://github.com/chef/chef-provisioning-aws/pull/248) ([tyler-ball](https://github.com/tyler-ball))
- Network acl [\#241](https://github.com/chef/chef-provisioning-aws/pull/241) ([dblessing](https://github.com/dblessing))
- Elasticache support [\#212](https://github.com/chef/chef-provisioning-aws/pull/212) ([dblessing](https://github.com/dblessing))

**Fixed bugs:**

- Specs fail with stack overflow message [\#240](https://github.com/chef/chef-provisioning-aws/issues/240)
- Failure when attempting to tag an aws\_vpc [\#218](https://github.com/chef/chef-provisioning-aws/issues/218)
- from\_image doesnt seem to work [\#211](https://github.com/chef/chef-provisioning-aws/issues/211)
- AWS Security Groups cannot be tagged [\#204](https://github.com/chef/chef-provisioning-aws/issues/204)
- machine converge instance not found error AWS::EC2::Errors::InvalidInstanceID::NotFound [\#158](https://github.com/chef/chef-provisioning-aws/issues/158)
- Should you get t1.micro instances by default? [\#29](https://github.com/chef/chef-provisioning-aws/issues/29)
- How about something for creating and assigning an IAM role to the server? [\#1](https://github.com/chef/chef-provisioning-aws/issues/1)
- Updating for Chef 12.4.x, fixes \#240 [\#250](https://github.com/chef/chef-provisioning-aws/pull/250) ([tyler-ball](https://github.com/tyler-ball))
- Adding a matcher which doesn't do any CRUD operations [\#248](https://github.com/chef/chef-provisioning-aws/pull/248) ([tyler-ball](https://github.com/tyler-ball))
- use wait\_for\_state before tagging VPC's, fixes \#218 [\#245](https://github.com/chef/chef-provisioning-aws/pull/245) ([metadave](https://github.com/metadave))
- Fix security group rule comparison [\#237](https://github.com/chef/chef-provisioning-aws/pull/237) ([dblessing](https://github.com/dblessing))
- Make destroy\_aws\_object work when using ec2-classic [\#209](https://github.com/chef/chef-provisioning-aws/pull/209) ([brainiac744](https://github.com/brainiac744))
- Support elb attributes, fixes \#138 [\#199](https://github.com/chef/chef-provisioning-aws/pull/199) ([dblessing](https://github.com/dblessing))
- Query Ubuntu for current AMI [\#197](https://github.com/chef/chef-provisioning-aws/pull/197) ([whiteley](https://github.com/whiteley))

**Closed issues:**

- S3 Bucket [\#222](https://github.com/chef/chef-provisioning-aws/issues/222)
- \(basic\_chef\_client::block line 57\) had an error: Net::HTTPServerException: 404 "Not Found" [\#217](https://github.com/chef/chef-provisioning-aws/issues/217)
- Cannot find AWS Credentials [\#210](https://github.com/chef/chef-provisioning-aws/issues/210)
- Ask Ubuntu for the latest Ubuntu image as the default image instead of hardcoding [\#196](https://github.com/chef/chef-provisioning-aws/issues/196)
- NoMethodError: undefined method `id' for "ami-e7f8d6d7" for aws\_launch\_configuration [\#160](https://github.com/chef/chef-provisioning-aws/issues/160)
- ELB attributes not supported [\#138](https://github.com/chef/chef-provisioning-aws/issues/138)
- Update of subnet fails due to incorrect comparison [\#137](https://github.com/chef/chef-provisioning-aws/issues/137)
- AWS::AutoScaling::Errors::ValidationError: At least one Availability Zone or VPC Subnet is required. [\#135](https://github.com/chef/chef-provisioning-aws/issues/135)
- Re-converging instances that were created with driver version \< 0.2.0 fails [\#86](https://github.com/chef/chef-provisioning-aws/issues/86)
- aws\_driver does not honor "with\_data\_center \[region\]" setting. [\#85](https://github.com/chef/chef-provisioning-aws/issues/85)
- Security Groups  [\#67](https://github.com/chef/chef-provisioning-aws/issues/67)
- Cleaner handling when trying :disassociate action on an already disassociated aws\_eip\_address [\#59](https://github.com/chef/chef-provisioning-aws/issues/59)
- bootstrap\_options need to be clarified [\#58](https://github.com/chef/chef-provisioning-aws/issues/58)
- aws\_security\_group doesn't show \(up to date\) message [\#50](https://github.com/chef/chef-provisioning-aws/issues/50)
- Remove update\_load\_balancer? [\#19](https://github.com/chef/chef-provisioning-aws/issues/19)

**Merged pull requests:**

- Update README.md [\#239](https://github.com/chef/chef-provisioning-aws/pull/239) ([ryancragun](https://github.com/ryancragun))
- additional documentation [\#236](https://github.com/chef/chef-provisioning-aws/pull/236) ([brandocorp](https://github.com/brandocorp))
- update README with rspec info [\#234](https://github.com/chef/chef-provisioning-aws/pull/234) ([metadave](https://github.com/metadave))

## [v1.2.1](https://github.com/chef/chef-provisioning-aws/tree/v1.2.1) (2015-05-28)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.2.0...v1.2.1)

**Merged pull requests:**

- Fixing \#158 and \#204 [\#213](https://github.com/chef/chef-provisioning-aws/pull/213) ([tyler-ball](https://github.com/tyler-ball))

## [v1.2.0](https://github.com/chef/chef-provisioning-aws/tree/v1.2.0) (2015-05-27)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.1.1...v1.2.0)

**Fixed bugs:**

- Tags are not converging idempotently [\#205](https://github.com/chef/chef-provisioning-aws/issues/205)
- Load Balancer no longer accepts security groups by name [\#203](https://github.com/chef/chef-provisioning-aws/issues/203)
- security\_groups bootstrap option doesn't work with an existing group [\#174](https://github.com/chef/chef-provisioning-aws/issues/174)
- Security groups can be referenced by group-name, don't need a data bag entry [\#194](https://github.com/chef/chef-provisioning-aws/pull/194) ([tyler-ball](https://github.com/tyler-ball))
- Feature: Propagate Virtual Private Gateway Routes for `aws\_route\_table` resource [\#151](https://github.com/chef/chef-provisioning-aws/pull/151) ([dblessing](https://github.com/dblessing))

**Closed issues:**

- ChefDK 0.6.0 and Client 12.3 with chef-provisioning AWS doesn't work in socketless mode [\#202](https://github.com/chef/chef-provisioning-aws/issues/202)
-  Invalid value 'Must specify both from and to ports with TCP/UDP.' for portRange. [\#183](https://github.com/chef/chef-provisioning-aws/issues/183)
- Unable to destroy on latest master [\#141](https://github.com/chef/chef-provisioning-aws/issues/141)
- Creation of aws\_security\_group fails if run from multiple machines \[local mode\] [\#49](https://github.com/chef/chef-provisioning-aws/issues/49)

**Merged pull requests:**

- Fixing a myriad of tests [\#208](https://github.com/chef/chef-provisioning-aws/pull/208) ([tyler-ball](https://github.com/tyler-ball))
- Updating ref files to run correctly [\#192](https://github.com/chef/chef-provisioning-aws/pull/192) ([tyler-ball](https://github.com/tyler-ball))
- Aws Tags [\#190](https://github.com/chef/chef-provisioning-aws/pull/190) ([patrick-wright](https://github.com/patrick-wright))

## [v1.1.1](https://github.com/chef/chef-provisioning-aws/tree/v1.1.1) (2015-04-28)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.1.0...v1.1.1)

**Closed issues:**

- machine :destroy RuntimeError when aws\_instance resource has been used in the recipe [\#189](https://github.com/chef/chef-provisioning-aws/issues/189)
- Can't provision windows server in a vpc [\#188](https://github.com/chef/chef-provisioning-aws/issues/188)

**Merged pull requests:**

- Updating to use the new \*spec.driver\_url syntax exposed in chef-provisioning 1.0 [\#191](https://github.com/chef/chef-provisioning-aws/pull/191) ([tyler-ball](https://github.com/tyler-ball))
- add destroy\_an\_aws\_object [\#186](https://github.com/chef/chef-provisioning-aws/pull/186) ([patrick-wright](https://github.com/patrick-wright))

## [v1.1.0](https://github.com/chef/chef-provisioning-aws/tree/v1.1.0) (2015-04-16)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v0.2.2...v1.1.0)

**Fixed bugs:**

- enhance aws\_ebs\_volume :availability\_zone to accept an AZ letter designation [\#184](https://github.com/chef/chef-provisioning-aws/issues/184)

**Closed issues:**

- Updating chef-provisioning-aws breaks chef-client -z functionality with ChefDK 0.4.0 \(current version\). [\#182](https://github.com/chef/chef-provisioning-aws/issues/182)

**Merged pull requests:**

- Updating destroy to remove instances and images on non-purge destroy [\#187](https://github.com/chef/chef-provisioning-aws/pull/187) ([tyler-ball](https://github.com/tyler-ball))
- update aws\_ebs\_volume :availability\_zone to exclude region setting [\#185](https://github.com/chef/chef-provisioning-aws/pull/185) ([patrick-wright](https://github.com/patrick-wright))
- Updated security group examples to use the correct hash key for ports. [\#181](https://github.com/chef/chef-provisioning-aws/pull/181) ([msonnabaum](https://github.com/msonnabaum))
- Fixed incorrect resource params in vpc example. [\#179](https://github.com/chef/chef-provisioning-aws/pull/179) ([msonnabaum](https://github.com/msonnabaum))
- Added version constraint for aws-sdk. [\#178](https://github.com/chef/chef-provisioning-aws/pull/178) ([msonnabaum](https://github.com/msonnabaum))
- AWS Proxy & Session Token Support [\#177](https://github.com/chef/chef-provisioning-aws/pull/177) ([afiune](https://github.com/afiune))
- network interface \(create, update, destroy\) [\#167](https://github.com/chef/chef-provisioning-aws/pull/167) ([patrick-wright](https://github.com/patrick-wright))
- Better AWS tests [\#152](https://github.com/chef/chef-provisioning-aws/pull/152) ([jkeiser](https://github.com/jkeiser))

## [v0.2.2](https://github.com/chef/chef-provisioning-aws/tree/v0.2.2) (2015-04-10)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.0.4...v0.2.2)

## [v1.0.4](https://github.com/chef/chef-provisioning-aws/tree/v1.0.4) (2015-04-07)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.0.3...v1.0.4)

**Closed issues:**

- Cloning resource attributes warnings at start of chef run [\#159](https://github.com/chef/chef-provisioning-aws/issues/159)

**Merged pull requests:**

- Potential fix for resource cloning showing back up [\#166](https://github.com/chef/chef-provisioning-aws/pull/166) ([tyler-ball](https://github.com/tyler-ball))

## [v1.0.3](https://github.com/chef/chef-provisioning-aws/tree/v1.0.3) (2015-04-07)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.0.2...v1.0.3)

**Merged pull requests:**

- Allow AwsDriver to work even if you haven't explicitly required 'chef/pr... [\#156](https://github.com/chef/chef-provisioning-aws/pull/156) ([jkeiser](https://github.com/jkeiser))

## [v1.0.2](https://github.com/chef/chef-provisioning-aws/tree/v1.0.2) (2015-04-06)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.0.1...v1.0.2)

## [v1.0.1](https://github.com/chef/chef-provisioning-aws/tree/v1.0.1) (2015-04-06)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.0.0...v1.0.1)

## [v1.0.0](https://github.com/chef/chef-provisioning-aws/tree/v1.0.0) (2015-04-02)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v1.0.0.rc.1...v1.0.0)

**Fixed bugs:**

- Add ability to ignore certain routes [\#172](https://github.com/chef/chef-provisioning-aws/pull/172) ([dblessing](https://github.com/dblessing))

**Closed issues:**

- Load Balancer deletion not working in 1.0.0.rc.1 [\#171](https://github.com/chef/chef-provisioning-aws/issues/171)

## [v1.0.0.rc.1](https://github.com/chef/chef-provisioning-aws/tree/v1.0.0.rc.1) (2015-04-01)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v0.5.0...v1.0.0.rc.1)

**Closed issues:**

- :stop action has disappeared on machine and machine\_image [\#161](https://github.com/chef/chef-provisioning-aws/issues/161)
- Second run on load balancer fails with AWS::Core::OptionGrammar::FormatError [\#130](https://github.com/chef/chef-provisioning-aws/issues/130)

**Merged pull requests:**

- Changelog and version for 0.5.0 release [\#153](https://github.com/chef/chef-provisioning-aws/pull/153) ([tyler-ball](https://github.com/tyler-ball))

## [v0.5.0](https://github.com/chef/chef-provisioning-aws/tree/v0.5.0) (2015-03-26)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v0.4.0...v0.5.0)

**Closed issues:**

- VPC main route table reference is impossible [\#146](https://github.com/chef/chef-provisioning-aws/issues/146)
- OpenSSL::SSL::SSLError connect error on machine converge [\#140](https://github.com/chef/chef-provisioning-aws/issues/140)
- `aws\_dhcp\_options` not able to be referenced by `aws\_vpc` resource [\#139](https://github.com/chef/chef-provisioning-aws/issues/139)
- Add the option to add AWS tags in the machine\_options [\#134](https://github.com/chef/chef-provisioning-aws/issues/134)
- Error when creating security group on VPC with outbound rule of 0.0.0.0/0 [\#129](https://github.com/chef/chef-provisioning-aws/issues/129)
- Cannot refer to a security group by security\_group\_id [\#128](https://github.com/chef/chef-provisioning-aws/issues/128)
- Converge fails if instance is deleted [\#125](https://github.com/chef/chef-provisioning-aws/issues/125)
- aws\_security\_group out of sync [\#121](https://github.com/chef/chef-provisioning-aws/issues/121)
- Unable to set subnet on a load\_balancer. [\#115](https://github.com/chef/chef-provisioning-aws/issues/115)

**Merged pull requests:**

- aws\_ebs\_volume \(jk/based on create\_update\_delete branch\) [\#142](https://github.com/chef/chef-provisioning-aws/pull/142) ([patrick-wright](https://github.com/patrick-wright))
- Standardize create/update/delete [\#136](https://github.com/chef/chef-provisioning-aws/pull/136) ([jkeiser](https://github.com/jkeiser))
- Make security groups idempotent, add better syntax [\#132](https://github.com/chef/chef-provisioning-aws/pull/132) ([jkeiser](https://github.com/jkeiser))
- Add DHCP options support [\#127](https://github.com/chef/chef-provisioning-aws/pull/127) ([jkeiser](https://github.com/jkeiser))
- Used managed entries for data bags, make resources responsible for referencing their object and entry [\#126](https://github.com/chef/chef-provisioning-aws/pull/126) ([jkeiser](https://github.com/jkeiser))

## [v0.4.0](https://github.com/chef/chef-provisioning-aws/tree/v0.4.0) (2015-03-04)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v0.3...v0.4.0)

**Closed issues:**

- Not able to create instance without public IP [\#120](https://github.com/chef/chef-provisioning-aws/issues/120)
- with\_driver no longer getting region from profile [\#116](https://github.com/chef/chef-provisioning-aws/issues/116)
- AWS::Core::OptionGrammar::FormatError updating a load balancer [\#114](https://github.com/chef/chef-provisioning-aws/issues/114)
- Exceptions when try to update load balancer [\#109](https://github.com/chef/chef-provisioning-aws/issues/109)
- No address associated with hostname" when using a proxy? [\#103](https://github.com/chef/chef-provisioning-aws/issues/103)
- AWS Profile not honored for aws\_vpc \(and possibly others\) [\#75](https://github.com/chef/chef-provisioning-aws/issues/75)

**Merged pull requests:**

- Fix \#116 and \#114 [\#117](https://github.com/chef/chef-provisioning-aws/pull/117) ([christinedraper](https://github.com/christinedraper))
- Security groups, subnets and schemes can be updated [\#108](https://github.com/chef/chef-provisioning-aws/pull/108) ([tyler-ball](https://github.com/tyler-ball))

## [v0.3](https://github.com/chef/chef-provisioning-aws/tree/v0.3) (2015-02-26)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/verbose_specs...v0.3)

**Fixed bugs:**

- machine resource not idempotent [\#15](https://github.com/chef/chef-provisioning-aws/issues/15)

**Closed issues:**

- destroying a machine image doesnt delete snapshots [\#94](https://github.com/chef/chef-provisioning-aws/issues/94)
- machine provisioning doesn't work for windows target [\#84](https://github.com/chef/chef-provisioning-aws/issues/84)
- Error on destroying a loadbalancer [\#82](https://github.com/chef/chef-provisioning-aws/issues/82)
- Multiple listeners defined in `load\_balancer` [\#81](https://github.com/chef/chef-provisioning-aws/issues/81)
- Provisioning only creates t1.micros [\#63](https://github.com/chef/chef-provisioning-aws/issues/63)
- machine\_file resource not working as the connect\_to\_machine method is not implemented [\#60](https://github.com/chef/chef-provisioning-aws/issues/60)
- Failure when creating security groups [\#57](https://github.com/chef/chef-provisioning-aws/issues/57)
- Feature: VPC subnet [\#38](https://github.com/chef/chef-provisioning-aws/issues/38)

**Merged pull requests:**

- Bug fixes for creating load balancers [\#106](https://github.com/chef/chef-provisioning-aws/pull/106) ([tyler-ball](https://github.com/tyler-ball))
- Fix undefined local variable or method `image\_id’ error [\#105](https://github.com/chef/chef-provisioning-aws/pull/105) ([schisamo](https://github.com/schisamo))

## [verbose_specs](https://github.com/chef/chef-provisioning-aws/tree/verbose_specs) (2015-02-16)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v0.2.1...verbose_specs)

**Closed issues:**

- aws\_security\_group throws an error on action :delete \(No resource, method, or local variable named `existing\_vpc'\) [\#92](https://github.com/chef/chef-provisioning-aws/issues/92)
- machine from\_image doesnt pick correct image [\#89](https://github.com/chef/chef-provisioning-aws/issues/89)
- No resource, method, or local variable named `existing\_vpc' when delete security group [\#74](https://github.com/chef/chef-provisioning-aws/issues/74)
- Delete action for aws\_vpc doesnt work [\#73](https://github.com/chef/chef-provisioning-aws/issues/73)
- image\_id should be a bootstrap\_options instead of machine\_option? [\#46](https://github.com/chef/chef-provisioning-aws/issues/46)
- driver image methods are empty [\#42](https://github.com/chef/chef-provisioning-aws/issues/42)

**Merged pull requests:**

- Fix specs require [\#99](https://github.com/chef/chef-provisioning-aws/pull/99) ([pburkholder](https://github.com/pburkholder))
- Fix VPC example to use aws\_subnet [\#78](https://github.com/chef/chef-provisioning-aws/pull/78) ([christinedraper](https://github.com/christinedraper))
- Ensure we pass a Hash to aws-sdk instances [\#72](https://github.com/chef/chef-provisioning-aws/pull/72) ([schisamo](https://github.com/schisamo))

## [v0.2.1](https://github.com/chef/chef-provisioning-aws/tree/v0.2.1) (2015-01-28)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v0.2...v0.2.1)

**Merged pull requests:**

- We must ensure that the transport is ready [\#71](https://github.com/chef/chef-provisioning-aws/pull/71) ([afiune](https://github.com/afiune))

## [v0.2](https://github.com/chef/chef-provisioning-aws/tree/v0.2) (2015-01-27)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v0.1.3...v0.2)

**Fixed bugs:**

- implement connect\_to\_machine [\#11](https://github.com/chef/chef-provisioning-aws/issues/11)

**Closed issues:**

- Add security\_group\_names to bootstrap\_options [\#48](https://github.com/chef/chef-provisioning-aws/issues/48)
- Can't specify ssh\_username via machine\_options [\#44](https://github.com/chef/chef-provisioning-aws/issues/44)

**Merged pull requests:**

- Adding website endpoint as stored attribute [\#39](https://github.com/chef/chef-provisioning-aws/pull/39) ([jaym](https://github.com/jaym))

## [v0.1.3](https://github.com/chef/chef-provisioning-aws/tree/v0.1.3) (2014-12-15)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v0.1.2...v0.1.3)

**Closed issues:**

- EC2 node attributes not available through ohai [\#37](https://github.com/chef/chef-provisioning-aws/issues/37)
- Default key doesn't work when creating machine resource [\#35](https://github.com/chef/chef-provisioning-aws/issues/35)
- Support ~/.aws/credentials [\#33](https://github.com/chef/chef-provisioning-aws/issues/33)
- :destroy action on load\_balancer is a noop [\#28](https://github.com/chef/chef-provisioning-aws/issues/28)
- What are the sane defaults for complete and converge in the machine resource? [\#25](https://github.com/chef/chef-provisioning-aws/issues/25)
- Default load\_balancer security group not working [\#24](https://github.com/chef/chef-provisioning-aws/issues/24)
- :destroy does not remove local client and node data [\#6](https://github.com/chef/chef-provisioning-aws/issues/6)

**Merged pull requests:**

- :allocate should ensure instance isn't terminated [\#40](https://github.com/chef/chef-provisioning-aws/pull/40) ([lynchc](https://github.com/lynchc))
- No support for EIP Addresses [\#36](https://github.com/chef/chef-provisioning-aws/pull/36) ([lynchc](https://github.com/lynchc))

## [v0.1.2](https://github.com/chef/chef-provisioning-aws/tree/v0.1.2) (2014-11-24)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v0.1.1...v0.1.2)

**Fixed bugs:**

- load\_balancer doesn't add machines on create [\#14](https://github.com/chef/chef-provisioning-aws/issues/14)
- Thoughts on using aws-sdk-core \(Version 2 of the sdk\)? [\#2](https://github.com/chef/chef-provisioning-aws/issues/2)

**Closed issues:**

- instance created when key name is not configured [\#7](https://github.com/chef/chef-provisioning-aws/issues/7)
- Implement security groups [\#4](https://github.com/chef/chef-provisioning-aws/issues/4)

**Merged pull requests:**

- Initial work for security groups and VPCs [\#34](https://github.com/chef/chef-provisioning-aws/pull/34) ([johnewart](https://github.com/johnewart))
- Default key support [\#26](https://github.com/chef/chef-provisioning-aws/pull/26) ([johnewart](https://github.com/johnewart))
- Combine update and create load balancer into idempotent action [\#22](https://github.com/chef/chef-provisioning-aws/pull/22) ([jkeiser](https://github.com/jkeiser))
- Make AWS machines convergent [\#18](https://github.com/chef/chef-provisioning-aws/pull/18) ([jkeiser](https://github.com/jkeiser))
- rename fog to aws [\#16](https://github.com/chef/chef-provisioning-aws/pull/16) ([patrick-wright](https://github.com/patrick-wright))

## [v0.1.1](https://github.com/chef/chef-provisioning-aws/tree/v0.1.1) (2014-11-05)
[Full Changelog](https://github.com/chef/chef-provisioning-aws/compare/v0.1...v0.1.1)

**Merged pull requests:**

- Rename to chef-provisioning-aws [\#9](https://github.com/chef/chef-provisioning-aws/pull/9) ([jkeiser](https://github.com/jkeiser))

## [v0.1](https://github.com/chef/chef-provisioning-aws/tree/v0.1) (2014-11-03)
**Merged pull requests:**

- Require V1 of AWS SDK [\#5](https://github.com/chef/chef-provisioning-aws/pull/5) ([jkeiser](https://github.com/jkeiser))
- Add EC2 auto-scaling groups and launch configs [\#3](https://github.com/chef/chef-provisioning-aws/pull/3) ([raskchanky](https://github.com/raskchanky))



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*
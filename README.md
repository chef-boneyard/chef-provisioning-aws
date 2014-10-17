# chef-metal-aws

A mostly-functional implementation of an AWS driver that doesn't use fog
(for a variety of reasons). It also implements AWS-specific resources to
manage such as SQS queues and SNS topics (currently) along with load
balancers (needs a non-production branch of metal at the moment) 

This is not quite ready for public consumption and is under active
development.

This requires the latest from chef-metal's load_balancer branch for some 
features like region support (until it gets merged into master, which should be soon)

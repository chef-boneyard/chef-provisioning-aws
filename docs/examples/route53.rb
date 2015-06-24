require 'chef/provisioning/aws_driver'

with_driver 'aws::us-east-1'

# this will fail. we use the domain name as a data bag key, but Route 53 will add a trailing dot, and
# furthermore Route 53 is content to have two HostedZones named "feegle.com.". in order to prevent unexpected
# results, we prevent domain names from ending with a dot.
aws_route53_hosted_zone "feegle.com."

# create a Route 53 Hosted Zone (which AWS will normalize to "feegle.com.").
aws_route53_hosted_zone "feegle.com"

# create a Route 53 Hosted Zone with a CNAME record.
# TODO(9/17/2015): maybe add an RRS attribute to append the enclosing zone name (like 'append_zone_name true').
aws_route53_hosted_zone "feegle.com" do
  record_sets {
    aws_route53_record_set "some-hostname CNAME" do
      rr_name "some-api-host.feegle.com"
      type "CNAME"
      ttl 3600
      resource_records ["some-other-host"]
    end
  }
end

# Route 53 ResourceRecordSets are mostly analogous to DNS resource records (RRs). in the AWS Console they look
# like first-class objects, but they don't have an AWS ID: only the RR name. (In other words, you can't have
# an A record and a TXT record both pointing to 'snarf.feegle.com'.)

# aws_route53_record_sets in the same aws_route53_hosted_zone resource are run as a transaction by AWS. You
# cannot currently (9/17/15) define an aws_route53_record_set elsewhere and refer to it here, and in fact I'm
# not sure if that's possible. you could probably define the record_sets block elsewhere and pass it to the
# resource, though.
aws_route53_hosted_zone "feegle.com" do
  record_sets {
    # the resource name can serve as the RR name.
    aws_route53_record_set "tiffany.feegle.com" do
      type "CNAME"
      ttl 1800
      resource_records ["a-different-host"]    # always an array of strings.
    end

    # or you can specify the RR name separately.
    aws_route53_record_set "aching" do
      rr_name "tiffany.feegle.com"
      type "A"
      ttl 3600
      resource_records [
        "141.222.2.2",
        "192.168.10.89"
      ]
    end
  }
end

# some RR types have restrictions on the resource_records values:
#  MX:    "<integer priority> <mail server hostname>"
#  SRV:   "<integer priority> <integer weight> <integer port> <server hostname>"
#  CNAME: may only have a single value.

# delete an individual RecordSet. the values must be the same as those currently in Route 53, or else an AWS
# error will bubble up.
aws_route53_hosted_zone "feegle.com" do
  record_sets {
    aws_route53_record_set "some-hostname CNAME" do
      action :destroy
      rr_name "some-api-host.feegle.com"
      type "CNAME"
      ttl 1800
      resource_records ["a-different-host"]
    end
  }
end

# calling :destroy on a zone will unconditionally wipe all of its RecordSets.
aws_route53_hosted_zone "feegle.com" do
  action :destroy
end

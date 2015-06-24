#!/usr/bin/env ruby

require 'json'
require 'pp'
require 'aws-sdk'

# it happens that you end up with a HostedZone with no Chef Server entry, and destroying it manually is
# tedious, because you have to delete all the ResourceRecordSets. this script will handle that for you.

doomed_zones = ARGV
doomed_zones.each do |doomed_zone|

  zones = JSON.parse(`aws route53 list-hosted-zones`)["HostedZones"]

  # requires an exact match, including the trailing dot. not such a bad thing, given the level of unrecoverable
  # deletion we're enabling.
  winner = zones.find { |z| z["Name"] == doomed_zone }

  if winner.nil?
    puts "Couldn't find zone '#{doomed_zone}'; candidates were #{zones.map {|z| z["Name"]} }"
    exit
  end

  zone_id = winner["Id"]

  rrsets = JSON.parse(`aws route53 list-resource-record-sets --hosted-zone-id=#{zone_id}`)["ResourceRecordSets"]

  rrsets.reject! { |rr| %w{SOA NS}.include?(rr["Type"]) }

  changes = rrsets.map do |rr|
    {
      action: "DELETE",
      resource_record_set: {
        name: rr["Name"],
        type: rr["Type"],
        ttl: rr["TTL"],
        resource_records: rr["ResourceRecords"].map { |o| { value: o["Value"] } },
      }
    }
  end

  req = {
    hosted_zone_id: winner["Id"],
    change_batch: { changes: changes },
  }

  client = Aws::Route53::Client.new
  client.change_resource_record_sets(req) if rrsets.size > 0
  client.delete_hosted_zone(id: zone_id)

  puts "Success! '#{doomed_zone}' deleted."
end
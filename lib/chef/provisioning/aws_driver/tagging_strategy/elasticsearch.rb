require 'chef/provisioning/aws_driver/aws_tagger'

module Chef::Provisioning::AWSDriver::TaggingStrategy
  class Elasticsearch

    attr_reader :client, :arn, :desired_tags

    def initialize(client, arn, desired_tags)
      @client = client
      @arn = arn
      @desired_tags = desired_tags
    end

    def current_tags
      resp = client.list_tags({arn: arn})
      Hash[resp.tag_list.map {|t| [t.key, t.value]}]
    rescue ::Aws::ElasticsearchService::Errors::ResourceNotFoundException
      Hash.new
    end

    def set_tags(tags)
      tags = tags.map {|k,v|
        if v.nil?
          {key: k}
        else
          {key: k, value: v}
        end
      }
      client.add_tags({
                        arn: arn,
                        tag_list: tags
                      })
    end

    def delete_tags(tag_keys)
      client.remove_tags({arn: arn,
                          tag_keys: tag_keys})
    end
  end
end

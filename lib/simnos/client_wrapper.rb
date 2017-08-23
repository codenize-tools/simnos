require 'forwardable'
require 'aws-sdk'
require 'simnos/filterable'

module Simnos
  class ClientWrapper
    extend Forwardable
    include Filterable

    def_delegators :@client, *%i/delete_topic get_topic_attributes create_topic set_topic_attributes set_subscription_attributes/

    def initialize(options)
      @options = options
      if options[:region]
        @client = Aws::SNS::Client.new(region: @options[:region])
      else
        @client = Aws::SNS::Client.new
      end
    end

    def topic_attrs(topic_arn: )
      @client.get_topic_attributes(topic_arn: topic_arn)
    end

    def topics
      results = {}
      next_token = nil
      begin
        resp = @client.list_topics(marker: next_token)
        resp.topics.each do |t|
          name = t.topic_arn.split(':').last
          next unless target?(name)
          results[name] = {
            topic: t,
            attrs: topic_attrs(topic_arn: t.topic_arn),
          }
        end
        next_token = resp.next_token
      end while next_token
      results
    end

    def region
      @client.config.region
    end

    private

    def topic_name(topic)
      topic.topic_arn.split(':').last
    end
  end
end

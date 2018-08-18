require 'forwardable'
require 'aws-sdk'
require 'simnos/filterable'

module Simnos
  class ClientWrapper
    extend Forwardable
    include Filterable

    def_delegators :@client, *%i/delete_topic get_topic_attributes create_topic set_topic_attributes set_subscription_attributes subscribe unsubscribe set_subscription_attributes/

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
        resp = @client.list_topics(next_token: next_token)
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

    def subscriptions_by_topic(topic_arn: )
      aws_subscriptions = []
      next_token = nil
      begin
        resp = @client.list_subscriptions_by_topic(topic_arn: topic_arn, next_token: next_token)
        aws_subscriptions.concat(resp.subscriptions)
        next_token = resp.next_token
      end while next_token
      aws_subscriptions.map do |aws_sub|
        if aws_sub.subscription_arn.split(':').length < 6
          Simnos.logger.warn("Subscription is not confirmed yet. #{aws_sub}".colorize(:red))
          next
        end
        resp = @client.get_subscription_attributes(subscription_arn: aws_sub.subscription_arn)
        SubscriptionWithAttributes.new(aws_sub, resp.attributes)
      end.compact
    end

    def region
      @client.config.region
    end

    private

    def topic_name(topic)
      topic.topic_arn.split(':').last
    end

    class SubscriptionWithAttributes
      # Source: https://docs.aws.amazon.com/sns/latest/api/API_SetSubscriptionAttributes.html
      ATTRIBUTES_WHITELIST = {
        'DeliveryPolicy' => nil,
        'FilterPolicy' => nil,
        'RawMessageDelivery' => "false",
      }

      extend Forwardable

      def initialize(aws_sub, raw_attributes)
        @aws_sub = aws_sub
        @attributes = raw_attributes.select do |key, value|
          ATTRIBUTES_WHITELIST.key?(key) && ATTRIBUTES_WHITELIST[key] != value
        end
      end

      def_delegators :@aws_sub, :endpoint, :owner, :protocol, :subscription_arn, :topic_arn
      attr_reader :attributes
    end
  end
end

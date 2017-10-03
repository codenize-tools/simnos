require 'simnos/utils'

module Simnos
  class DSL
    class Subscription
      include Simnos::TemplateHelper

      def create
        Simnos.logger.info("Create Topic(#{@aws_topic[:topic].topic_arn.split(':').last}) Subscription. protocol: #{protocol.inspect}, endpoint: #{endpoint.inspect}#{@options[:dry_run] ? ' [dry-run]' : ''}")
        return if @options[:dry_run]

        client.subscribe(
          topic_arn: @aws_topic[:topic].topic_arn,
          protocol: protocol,
          endpoint: endpoint,
        )
      end

      def aws_topic(aws_topic)
        @aws_topic = aws_topic
        self
      end

      def initialize(context, topic: , protocol: , endpoint: )
        @context = context
        @options = @context.options
        @topic = topic
        @protocol = protocol
        @endpoint = endpoint
      end

      attr_reader :topic, :protocol, :endpoint

      private

      def client
        @client ||= Simnos::ClientWrapper.new(@context)
      end
    end
  end
end

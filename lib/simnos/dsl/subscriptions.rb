require 'simnos/utils'
require 'simnos/dsl/subscription'

module Simnos
  class DSL
    class Subscriptions
      include Simnos::TemplateHelper

      def initialize(context, topic, &block)
        @context = context
        @topic = topic

        @result = []

        instance_eval(&block)
      end

      attr_reader :result

      private

      def subscription(protocol: , endpoint: , attributes: nil)
        @result << Subscription.new(@context, topic: @topic, protocol: protocol, endpoint: endpoint, attributes: attributes)
      end
    end
  end
end

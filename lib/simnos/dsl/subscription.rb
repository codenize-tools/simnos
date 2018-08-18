require 'colorize'
require 'simnos/utils'

module Simnos
  class DSL
    class Subscription
      include Simnos::TemplateHelper

      def create
        Simnos.logger.info("Create Topic(#{@aws_topic[:topic].topic_arn.split(':').last}) Subscription. #{inspect_for_log}#{@options[:dry_run] ? ' [dry-run]' : ''}".colorize(:green))
        return if @options[:dry_run]

        client.subscribe(
          topic_arn: @aws_topic[:topic].topic_arn,
          protocol: protocol,
          endpoint: endpoint,
          attributes: normalize_attributes(attributes),
        )
      end

      def aws_topic(aws_topic)
        @aws_topic = aws_topic
        self
      end

      def initialize(context, topic: , protocol: , endpoint: , attributes: )
        @context = context
        @options = @context.options
        @topic = topic
        @protocol = protocol
        @endpoint = endpoint
        @attributes = attributes
      end

      MODIFY_ATTRS = %w/DeliveryPolicy FilterPolicy RawMessageDelivery/

      def modify_attrs
        return unless attributes
        MODIFY_ATTRS.each do |attr_name|
          modify_attr(attributes[attr_name], attr_name)
        end
      end

      def modify_attr(_dsl_val, attr_name)
        aws_val = attribute_value_to_object(@aws_sub.attributes[attr_name])
        dsl_val = attribute_value_to_object(_dsl_val)
        return if dsl_val == aws_val

        Simnos.logger.debug('--- aws ---')
        Simnos.logger.debug(aws_val.pretty_inspect)
        Simnos.logger.debug('--- dsl ---')
        Simnos.logger.debug(dsl_val.pretty_inspect)
        Simnos.logger.info("Modify Subscription protocol: #{protocol.inspect}, endpoint: #{masked_endpoint.inspect} #{attr_name} attributes.#{@options[:dry_run] ? ' [dry-run]' : ''}".colorize(:blue))
        dsl_attrs = {
          attribute_name: attr_name,
          attribute_value: (dsl_val.nil? ? {} : dsl_val),
        }
        diff = Simnos::Utils.diff({
          attribute_name: attr_name,
          attribute_value: aws_val,
        }, dsl_attrs,
          color: @options[:color],
        )
        dsl_attrs[:attribute_value] = dsl_attrs[:attribute_value].to_json
        Simnos.logger.info("<diff>\n#{diff}")
        return if @options[:dry_run]

        client.set_subscription_attributes(dsl_attrs.merge(subscription_arn: @aws_sub.subscription_arn))
      end

      def attributes_updated?
        normalize_attributes(@aws_sub.attributes) != normalize_attributes(attributes)
      end

      def aws(aws_sub)
        @aws_sub = aws_sub
      end

      attr_reader :topic, :protocol, :attributes

      # We have to mask endpoint because SNS returns masked endpoint from API
      def masked_endpoint
        if URI.extract(@endpoint, ['http', 'https']).empty?
          return endpoint
        end
        uri = URI.parse(endpoint)
        if md = uri.userinfo&.match(/(.*):(.*)/)
          uri.userinfo = "#{md[1]}:****"
        end
        uri.to_s
      end

      def endpoint
        secret_expander = @options[:secret_expander]
        if secret_expander
          secret_expander.expand(@endpoint)
        else
          @endpoint
        end
      end

      private

      def attribute_value_to_object(val)
        return val unless val
        return val if !!val == val
        val.is_a?(String) ? JSON.parse(val) : val
      end

      def normalize_attributes(attr)
        nattr = attr.dup
        attr.keys.sort.each do |key|
          nattr[key] = attr[key].is_a?(Hash) ? attr[key].to_json : attr[key]
        end
        nattr
      end

      def inspect_for_log
        attributes_log = attributes ? ", attributes: #{attributes}" : ''
        "protocol: #{protocol.inspect}, endpoint: #{masked_endpoint.inspect}#{attributes_log}"
      end

      def client
        @client ||= Simnos::ClientWrapper.new(@context)
      end
    end
  end
end

require 'simnos/utils'
require 'simnos/dsl/subscriptions'

module Simnos
  class DSL
    class Topic
      include Simnos::TemplateHelper

      class Result
        ATTRIBUTES = %i/name display_name subscriptions_pending subscriptions_confirmed subscriptions_deleted effective_delivery_policy policy topic_arn subscriptions aws_topic opt_out_subscriptions/
        attr_accessor *ATTRIBUTES

        def initialize(context)
          @context = context
          @options = context.options
          @subscriptions = []
        end

        def to_h
          Hash[ATTRIBUTES.sort.map { |name| [name, public_send(name)] }]
        end

        CREATE_KEYS = %i/name/
        def create_option
          to_h.select { |k, _| CREATE_KEYS.include?(k) }
        end

        def create
          Simnos.logger.info("Create Topic #{name}.#{@options[:dry_run] ? ' [dry-run]' : ''}")
          return { topic: Hashie::Mash.new(topic_arn: 'not yet created') } if @options[:dry_run]

          resp = client.create_topic(name: name)
          # save topic_arn
          topic_arn = resp.topic_arn
          {
            topic: resp,
            attrs: client.topic_attrs(topic_arn: resp.topic_arn)
          }
        end

        def aws(aws_topic)
          @aws_topic = aws_topic
          self
        end

        def attrs_updated?
          to_h
        end

        def modify
          modify_attrs
          modify_attrs_hash
        end

        MODIFY_ATTRS = {
          display_name: 'DisplayName',
          #subscriptions_pending: 'SubscriptionsPending',
          #subscriptions_confirmed: 'SubscriptionsConfirmed',
          #subscriptions_deleted: 'SubscriptionsDeleted',
        }
        def modify_attrs
          MODIFY_ATTRS.each do |prop_name, attr_name|
            modify_attr(send(prop_name), attr_name)
          end
        end

        def modify_attr(dsl_val, attr_name)
          aws_val = @aws_topic[:attrs].attributes[attr_name]
          return if dsl_val == aws_val

          Simnos.logger.debug('--- aws ---')
          Simnos.logger.debug(@aws_topic[:attrs].attributes.pretty_inspect)
          Simnos.logger.debug('--- dsl ---')
          Simnos.logger.debug(dsl_val)
          Simnos.logger.info("Modify Topic `#{name}` #{attr_name} attributes.#{@options[:dry_run] ? ' [dry-run]' : ''}")
          dsl_attrs = {
            attribute_name: attr_name,
            attribute_value: dsl_val,
          }
          diff = Simnos::Utils.diff({
            attribute_name: attr_name,
            attribute_value: aws_val,
          }, dsl_attrs,
            color: @options[:color],
          )
          Simnos.logger.info("<diff>\n#{diff}")
          return if @options[:dry_run]

          client.set_topic_attributes(dsl_attrs.merge(topic_arn: @aws_topic[:topic].topic_arn))
        end

        def modify_attr_hash(dsl_val, attr_name)
          aws_val = JSON.parse(@aws_topic[:attrs].attributes[attr_name])
          return if dsl_val == aws_val
          Simnos.logger.info("Modify Topic `#{name}` #{attr_name} attributes.#{@options[:dry_run] ? ' [dry-run]' : ''}")
          dsl_attrs = {
            attribute_name: attr_name,
            attribute_value: dsl_val,
          }
          diff = Simnos::Utils.diff({
            attribute_name: attr_name,
            attribute_value: aws_val,
          }, dsl_attrs,
            color: @options[:color],
          )
          Simnos.logger.info("<diff>\n#{diff}")
          return if @options[:dry_run]

          dsl_attrs.merge!(topic_arn: @aws_topic[:topic].topic_arn)
          dsl_attrs[:attribute_value] = dsl_attrs[:attribute_value].to_json
          if attr_name == 'Policy'
            client.set_topic_attributes(dsl_attrs)
          elsif attr_name == 'EffectiveDeliveryPolicy'
            dsl_attrs[:attribute_name] = 'DeliveryPolicy'
            client.set_topic_attributes(dsl_attrs)
          end
        end

        MODIFY_ATTRS_HASH = {
          effective_delivery_policy: 'EffectiveDeliveryPolicy',
          policy: 'Policy',
        }
        def modify_attrs_hash
          MODIFY_ATTRS_HASH.each do |prop_name, attr_name|
            modify_attr_hash(send(prop_name), attr_name)
          end
        end

        def client
          @client ||= Simnos::ClientWrapper.new(@context)
        end
      end

      def initialize(context, name, &block)
        @name = name
        @context = context.merge(name: name)

        @result = Result.new(@context)
        @result.name = name

        instance_eval(&block)
      end

      def result
        @result
      end

      private

      def display_name(display_name)
        @result.display_name = display_name
      end

      def subscriptions_pending(subscriptions_pending)
        @result.subscriptions_pending = subscriptions_pending
      end

      def subscriptions_confirmed(subscriptions_confirmed)
        @result.subscriptions_confirmed = subscriptions_confirmed
      end

      def subscriptions_deleted(subscriptions_deleted)
        @result.subscriptions_deleted = subscriptions_deleted
      end

      def effective_delivery_policy
        @result.effective_delivery_policy = yield
      end

      def policy
        @result.policy = yield
      end

      def subscriptions(opt_out: false, &block)
        if opt_out
          @result.opt_out_subscriptions = true
          return
        end
        @result.subscriptions = Subscriptions.new(@context, self, &block).result
      end
    end
  end
end

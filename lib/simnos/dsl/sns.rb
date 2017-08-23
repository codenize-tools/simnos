require 'ostruct'
require 'simnos/dsl/topic'

module Simnos
  class DSL
    class SNS
      include Simnos::TemplateHelper

      attr_reader :result

      def initialize(context, topics, &block)
        @context = context

        @result  = OpenStruct.new(
          topics: topics
        )
        @names = topics.map(&:name)
        instance_eval(&block)
      end

      private

      def topic(name, &block)
        if @names.include?(name)
          raise "#{name} is already defined"
        end

        @result.topics << Topic.new(@context, name, &block).result
        @names << name
      end
    end
  end
end

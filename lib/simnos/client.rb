require 'colorize'
require 'pp'
require 'simnos/client_wrapper'
require 'simnos/converter'
require 'simnos/dsl'
require 'simnos/filterable'
require 'simnos/secret_expander'

module Simnos
  class Client
    include Filterable
    MAGIC_COMMENT = <<-EOS
# -*- mode: ruby -*-
# vi: set ft=ruby :
    EOS

    def initialize(filepath, options = {})
      @filepath = filepath
      @options = options
      @options[:secret_expander] = SecretExpander.new(@options[:secret_provider]) if @options[:secret_provider]
    end

    def apply
      Simnos.logger.info("Applying...#{@options[:dry_run] ? ' [dry-run]' : ''}")
      dsl = load_file(@filepath)

      dsl.snss.each do |region, sns|
        @options[:region] = region
        Simnos.logger.info("region: #{region}")
        aws_topics_by_name = client.topics
        traverse_topics(sns.topics, aws_topics_by_name)
      end
    end

    def export
      Simnos.logger.info("Exporting...#{@options[:dry_run] ? ' [dry-run]' : ''}")

      topics_by_name = client.topics

      if @options[:with_subscriptions]
        topics_by_name.each do |name, topic|
          Simnos.logger.debug("exporting subscriptions of #{topic[:topic].topic_arn}")
          topic[:subscriptions] = client.subscriptions_by_topic(topic_arn: topic[:topic].topic_arn)
        end
      end
      region = client.region

      path = Pathname.new(@filepath)
      base_dir = path.parent
      if @options[:split]
        FileUtils.mkdir_p(base_dir)
        topics_by_name.each do |name, aws|
          Converter.new({name => aws}, region).convert do |dsl|
            sns_file = base_dir.join("#{name}.sns")
            Simnos.logger.info("Export #{sns_file}")
            open(sns_file, 'wb') do |f|
              f.puts MAGIC_COMMENT
              f.puts dsl
            end
          end
        end
      else
        Converter.new(topics_by_name, region).convert do |dsl|
          FileUtils.mkdir_p(base_dir)
          Simnos.logger.info("Export #{path}")
          open(path, 'wb') do |f|
            f.puts MAGIC_COMMENT
            f.puts dsl
          end
        end
      end
    end

    private

    def target_subscription?(endpoint)
      unless @options[:include_endpoints].empty?
        unless @options[:include_endpoints].include?(endpoint)
          Simnos.logger.debug("skip subscription(with include-endpoints option) #{endpoint}")
          return false
        end
      end

      unless @options[:exclude_endpoints].empty?
        if @options[:exclude_endpoints].any? { |regex| endpoint =~ regex }
          Simnos.logger.debug("skip subscription(with exclude-endpoints option) #{endpoint}")
          return false
        end
      end
      true
    end

    def delete_subscriptions(aws_topic, aws_sub_by_key)
      aws_sub_by_key.each do |key, aws_sub|
        Simnos.logger.info("Delete Topic(#{aws_topic[:topic].topic_arn.split(':').last}) Subscription. protocol: #{key[0].inspect}, endpoint: #{key[1].inspect}.#{@options[:dry_run] ? ' [dry-run]' : ''}".colorize(:red))
        if aws_sub.subscription_arn.split(':').length < 6
          Simnos.logger.warn("Can not delete Subscription `#{aws_sub.subscription_arn}`")
          next
        end
        next if @options[:dry_run]

        client.unsubscribe(subscription_arn: aws_sub.subscription_arn)
      end
    end

    def traverse_subscriptions(aws_topic, dsl_subscriptions, aws_subscriptions)
      dsl_sub_by_key = dsl_subscriptions.each_with_object({}) do |dsl_sub, h|
        next unless target_subscription?(dsl_sub.endpoint)
        h[[dsl_sub.protocol, dsl_sub.masked_endpoint]] = dsl_sub
      end
      aws_sub_by_key = aws_subscriptions.each_with_object({}) do |aws_sub, h|
        next unless target_subscription?(aws_sub.endpoint)
        h[[aws_sub.protocol, aws_sub.endpoint]] = aws_sub
      end

      if @options[:recreate_subscriptions]
        Simnos.logger.info("Subscription recreation flag is on.#{@options[:dry_run] ? ' [dry-run]' : ''}")
        delete_subscriptions(aws_topic, aws_sub_by_key)
        aws_sub_by_key = {}
      end

      # create
      dsl_sub_by_key.reject { |key, _| aws_sub_by_key[key] }.each do |key, dsl_sub|
        dsl_sub.aws_topic(aws_topic).create
      end

      # there is no way to update subscriptions
      dsl_sub_by_key.each do |key, dsl_sub|
        next unless aws_sub = aws_sub_by_key.delete(key)
        dsl_sub.aws(aws_sub)
        dsl_sub.modify_attrs
      end

      unless @options[:only_create_subscriptions]
        # delete
        delete_subscriptions(aws_topic, aws_sub_by_key)
      end
    end

    def traverse_topics(dsl_topics_all, aws_topics_by_name)
      dsl_topics = dsl_topics_all.select { |t| target?(t.name) }
      # create
      dsl_topics.reject { |t| aws_topics_by_name[t.name] }.each do |dsl_topic|
        aws_topic = dsl_topic.create

        unless @options[:dry_run]
          aws_topics_by_name[dsl_topic.name] = aws_topic
        end
        if @options[:with_subscriptions] && !dsl_topic.opt_out_subscriptions
          traverse_subscriptions(aws_topic, dsl_topic.subscriptions, [])
        end
      end

      # modify
      dsl_topics.each do |dsl_topic|
        next unless aws_topic = aws_topics_by_name.delete(dsl_topic.name)

        dsl_topic.aws(aws_topic).modify

        if @options[:with_subscriptions] && !dsl_topic.opt_out_subscriptions
          aws_subscriptions = client.subscriptions_by_topic(topic_arn: aws_topic[:topic].topic_arn)
          traverse_subscriptions(aws_topic, dsl_topic.subscriptions, aws_subscriptions)
        end
      end

      # delete
      aws_topics_by_name.each do |name, aws_topic|
        Simnos.logger.info("Delete Topic #{name}.#{@options[:dry_run] ? ' [dry-run]' : ''}".colorize(:red))
        next if @options[:dry_run]

        client.delete_topic(topic_arn: aws_topic[:topic].topic_arn)
      end
    end

    def load_file(file)
      open(file) do |f|
        DSL.define(f.read, file, @options).result
      end
    end

    def client
      @client_by_region ||= {}
      @client_by_region[@options[:region]] ||= ClientWrapper.new(@options)
    end
  end
end

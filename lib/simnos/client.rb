require 'pp'
require 'simnos/client_wrapper'
require 'simnos/converter'
require 'simnos/dsl'
require 'simnos/filterable'

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

    def traverse_topics(dsl_topics_all, aws_topics_by_name)
      dsl_topics = dsl_topics_all.select { |t| target?(t.name) }
      # create
      dsl_topics.reject { |t| aws_topics_by_name[t.name] }.each do |dsl_topic|
        aws_topics_by_name[dsl_topic.name] = dsl_topic.create
      end

      # modify
      dsl_topics.each do |dsl_topic|
        next unless aws_topic = aws_topics_by_name.delete(dsl_topic.name)

        dsl_topic.aws(aws_topic).modify
      end

      # delete
      aws_topics_by_name.each do |name, aws_topic|
        Simnos.logger.info("Delete Topic #{name}")
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

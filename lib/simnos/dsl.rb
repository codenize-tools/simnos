require 'hashie'
require 'simnos/template_helper'
require 'simnos/dsl/sns'

module Simnos
  class DSL
    include Simnos::TemplateHelper

    class << self
      def define(source, filepath, options)
        self.new(filepath, options) do
          eval(source, binding, filepath)
        end
      end
    end

    attr_reader :result

    def initialize(filepath, options, &block)
      @filepath = filepath
      @result = OpenStruct.new(snss: Hashie::Mash.new)

      @context = Hashie::Mash.new(
        filepath: filepath,
        templates: {},
        options: options,
      )

      instance_eval(&block)
    end

    def require(file)
      albfile = (file =~ %r|\A/|) ? file : File.expand_path(File.join(File.dirname(@filepath), file))

      if File.exist?(albfile)
        instance_eval(File.read(albfile), albfile)
      elsif File.exist?("#{albfile}.rb")
        instance_eval(File.read("#{albfile}.rb"), "#{albfile}.rb")
      else
        Kernel.require(file)
      end
    end

    def template(name, &block)
      @context.templates[name.to_s] = block
    end

    def sns(region = nil, &block)
      current_region = @context[:region] = region || ENV['AWS_DEFAULT_REGION'] || ENV.fetch('AWS_REGION')
      topics = @result.snss[current_region] || []
      @result.snss[current_region] = SNS.new(@context, topics, &block).result
    end
  end
end

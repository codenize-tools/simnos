require 'simnos'
require 'optparse'
require 'pathname'

module Simnos
  class CLI
    def self.start(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv.dup
      @help = argv.empty?
      @filepath = 'SNSfile'
      @options = {
        color: true,
        includes: [],
        excludes: [],
      }
      parser.order!(@argv)
    end

    def run
      if @help
        puts parser.help
      elsif @apply
        Apply.new(@filepath, @options).run
      elsif @export
        Export.new(@filepath, @options).run
      end
    end

    private

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.version = VERSION
        opts.on('-h', '--help', 'show help') { @help = true }
        opts.on('-v', '--debug', 'show debug log') { Simnos.logger.level = Logger::DEBUG }
        opts.on('-a', '--apply', 'apply DSL') { @apply = true }
        opts.on('-e', '--export', 'export to DSL') { @export = true }
        opts.on('-n', '--dry-run', 'dry run') { @options[:dry_run] = true }
        opts.on('-f', '--file FILE', 'use selected DSL file') { |v| @filepath = v }
        opts.on('-s', '--split', 'split export DSL file to 1 per topic') { @options[:split] = true }
        opts.on('',   '--no-color', 'no color') { @options[:color] = false }
        opts.on('',   '--with-subscriptions', 'manage subscriptions') { @options[:with_subscriptions] = true }
        opts.on('',   '--only-create-subscriptions', 'only create subscriptions(recreation will occur with recreate-subscriptions option, even this option is enabled)') { @options[:only_create_subscriptions] = true }
        opts.on('',   '--recreate-subscriptions', 'recreate subscriptions') { @options[:recreate_subscriptions] = true }
        opts.on('',   '--secret-provider NAME', 'use secret value expansion') { |v| @options[:secret_provider] = v }
        opts.on('-i', '--include-names NAMES', 'include SNS names', Array) { |v| @options[:includes] = v }
        opts.on('-x', '--exclude-names NAMES', 'exclude SNS names by regex', Array) do |v|
          @options[:excludes] = v.map! do |name|
            name =~ /\A\/(.*)\/\z/ ? Regexp.new($1) : Regexp.new("\A#{Regexp.escape(name)}\z")
          end
        end
      end
    end

    class Apply
      def initialize(filepath, options)
        @filepath = filepath
        @options = options
      end

      def run
        require 'simnos/client'
        result = Client.new(@filepath, @options).apply
      end
    end

    class Export
      def initialize(filepath, options)
        @filepath = filepath
        @options = options
      end

      def run
        require 'simnos/client'
        result = Client.new(@filepath, @options).export
      end
    end
  end
end

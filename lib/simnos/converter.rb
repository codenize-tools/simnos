require 'erb'

module Simnos
  class Converter
    def initialize(topics_by_name, region)
      @topics_by_name = topics_by_name
      @region = region
    end

    def convert
      yield output_topic(@topics_by_name, @region)
    end

    private

    def output_topic(topics_by_name, region)
      path = Pathname.new(File.expand_path('../', __FILE__)).join('output_topic.erb')
      ERB.new(path.read, nil, '-').result(binding)
    end
  end
end

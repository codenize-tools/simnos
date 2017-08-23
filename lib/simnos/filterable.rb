module Simnos
  module Filterable
    def target?(topic_name)
      unless @options[:includes].empty?
        unless @options[:includes].include?(topic_name)
          Simnos.logger.debug("skip topic(with include-names option) #{topic_name}")
          return false
        end
      end

      unless @options[:excludes].empty?
        if @options[:excludes].any? { |regex| topic_name =~ regex }
          Simnos.logger.debug("skip topic(with exclude-names option) #{topic_name}")
          return false
        end
      end
      true
    end
  end
end

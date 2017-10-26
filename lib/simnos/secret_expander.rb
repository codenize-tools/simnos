require 'strscan'

module Simnos
  class ExpansionError < StandardError
  end

  class SecretExpander
    Literal = Struct.new(:literal)
    Variable = Struct.new(:name)

    def initialize(provider_name)
      @provider = load_provider(provider_name)
      @asked_variables = {}
    end

    def expand(str)
      tokens = parse(str)
      variables = Set.new
      tokens.each do |token|
        if token.is_a?(Variable)
          unless @asked_variables.include?(token.name)
            variables << token.name
          end
        end
      end

      unless variables.empty?
        @provider.ask(variables).each do |k, v|
          @asked_variables[k] = v
        end
      end

      tokens.map do |token|
        case token
        when Literal
          token.literal
        when Variable
          @asked_variables.fetch(token.name)
        else
          raise ExpansionError.new("Unknown token type: #{token.class}")
        end
      end.join
    end

    private

    def parse(value)
      s = StringScanner.new(value)
      tokens = []
      pos = 0
      while s.scan_until(/\$\{(.*?)\}/)
        pre = s.string.byteslice(pos...(s.pos - s.matched.size))
        var = s[1]
        unless pre.empty?
          tokens << Literal.new(pre)
        end
        if var.empty?
          raise ExpansionError.new('Empty interpolation is not allowed')
        else
          tokens << Variable.new(var)
        end
        pos = s.pos
      end
      unless s.rest.empty?
        tokens << Literal.new(s.rest)
      end
      tokens
    end

    def load_provider(name)
      require "simnos/secret_providers/#{name}"
      Simnos::SecretProviders.const_get(name.split('_').map(&:capitalize).join('')).new
    end
  end
end

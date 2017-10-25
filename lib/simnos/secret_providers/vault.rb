module Simnos
  module SecretProviders
    class Vault
      def ask(keys)
        puts '=' * 100
        puts 'ask'
        p keys
        {'password' => 'very_secret'}
      end
    end
  end
end

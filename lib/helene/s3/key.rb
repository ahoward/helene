module Helene
  module S3
    class Key < ::String
      class << Key
        def clean(*keys)
          key = File.join(*keys.flatten.compact)
          key = key.to_s.strip
          key.squeeze!('/')
          key.sub!(%r|^[./]+|, '')
          key.sub!(%r|/+$|, '')
          key
        end
        alias_method 'cleanpath', 'clean'
      end

      attr_accessor :prefix

      def initialize key, options = {}
        options.to_options!
        @prefix = options[:prefix]
        replace Key.clean(@prefix ? File.join(@prefix, key.to_s) : key.to_s)
      end
    end
  end
end

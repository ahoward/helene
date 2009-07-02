module Helene
  module S3
    class Key < ::String
      class << Key
        def for(key, *args)
          return key if(key.is_a?(Key) and args.empty?)
          new(key, *args)
        end

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
        if @prefix.nil?
          @prefix, basename = File.split(key.to_s)
        end
        #replace Key.clean(@prefix ? File.join(@prefix, key.to_s) : key.to_s)
        replace Key.clean(@prefix, key)
      end

      def initialize(*parts)
        replace Key.clean(*parts)
      end

      def prefix
        File.dirname(self)
      end
    end
  end
end

module Helene
  module Sdb
    class << Sdb
      def create_connection(*args)
        options = args.extract_options!.to_options!

        aws_access_key_id =
          options.delete(:aws_access_key_id) || args.shift || Helene.aws_access_key_id

        aws_secret_access_key =
          options.delete(:aws_secret_access_key) || args.shift || Helene.aws_secret_access_key

        # options[:multi_thread] = true unless options.has_key?(:multi_thread)

        Interface.new(aws_access_key_id, aws_secret_access_key, options)
      end

      def connections(&block)
        block ? @connections.get(&block) : @connections
      end

      class ConnectionProxy < BlankSlate
        def method_missing(method, *args, &block)
          Sdb.connections do |connection|
            connection.send(method, *args, &block)
          end
        end
      end

      def connection
        @connection ||= ConnectionProxy.new
      end
    end
    @connections = ObjectPool.new(:size => 4){ create_connection }
  end
end

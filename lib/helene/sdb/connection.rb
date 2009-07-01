module Helene
  module Sdb
    class << Sdb
      def create_connection(*args)
        options = args.extract_options!.to_options!

        access_key_id =
          options.delete(:access_key_id) || args.shift || Helene.access_key_id

        secret_access_key =
          options.delete(:secret_access_key) || args.shift || Helene.secret_access_key

        Interface.new(access_key_id, secret_access_key, options)
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

    @connections = ObjectPool.new(:size => 8){ create_connection }
  end
end

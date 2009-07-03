module Helene
  module S3
    class << S3
      def create_connection(*args)
        options = args.extract_options!.to_options!

        access_key_id =
          options.delete(:access_key_id) || args.shift || Helene.access_key_id

        secret_access_key =
          options.delete(:secret_access_key) || args.shift || Helene.secret_access_key

        RightAws::S3Interface.new(access_key_id, secret_access_key, options)
      end

      def connections(&block)
        block ? @connections.get(&block) : @connections
      end

      class ConnectionProxy < BlankSlate
        def method_missing(method, *args, &block)
          S3.connections do |connection|
            connection.send(method, *args, &block)
          end
        end
      end

      def connection
        @connection ||= ConnectionProxy.new
      end
      alias_method 'interface', 'connection'

      load 'helene/s3/bucket.rb'
      load 'helene/s3/key.rb'
      load 'helene/s3/object.rb'
      load 'helene/s3/owner.rb'
      load 'helene/s3/grantee.rb'
    end
    @connections = ObjectPool.new(:size => 8){ create_connection }
  end
end

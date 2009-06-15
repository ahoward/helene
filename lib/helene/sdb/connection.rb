module Helene
  module Sdb
    class << Sdb
      def establish_connection(*args)
        options = args.extract_options!.to_options!

        aws_access_key_id =
          options.delete(:aws_access_key_id) || args.shift || Helene.aws_access_key_id

        aws_secret_access_key =
          options.delete(:aws_secret_access_key) || args.shift || Helene.aws_secret_access_key

        options[:multi_thread] = true unless options.has_key?(:multi_thread)

        Thread.current[:helene_sdb_connection] = Interface.new(aws_access_key_id, aws_secret_access_key, options)
      end

      def connection
        Thread.current[:helene_sdb_connection] ||= establish_connection
      ensure
        raise Error.new('Connection to SDB is not established') unless Thread.current[:helene_sdb_connection]
      end
      alias_method 'interface', 'connection'
    end
  end
end

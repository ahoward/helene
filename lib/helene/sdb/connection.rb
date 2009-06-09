module Helene
  module Sdb
    class << Sdb
      def establish_connection(*args)
        options = args.extract_options!.to_options!
        aws_access_key_id =
          options.delete(:aws_access_key_id) || args.shift || Helene.aws_access_key_id
        aws_secret_access_key =
          options.delete(:aws_secret_access_key) || args.shift || Helene.aws_secret_access_key
        @connection = Interface.new(aws_access_key_id, aws_secret_access_key, options)
      end

      def connection
        @connection ||= establish_connection
      ensure
        raise Error.new('Connection to SDB is not established') unless @connection
      end
      alias_method 'interface', 'connection'
    end
  end
end

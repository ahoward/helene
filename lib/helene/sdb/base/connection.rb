module Helene
  module Sdb
    class Base
      class << Base
        def connection
          @connection ||= Sdb.connection
        end
        alias_method 'interface', 'connection'

        def establish_connection(*args)
          options = args.extract_options!.to_options!
          aws_access_key_id =
            options.delete(:aws_access_key_id) || args.shift || Helene.aws_access_key_id
          aws_secret_access_key =
            options.delete(:aws_secret_access_key) || args.shift || Helene.aws_secret_access_key
          options.reverse_merge(:nil_representation => nil_representation)
          @connection = Interface.new(aws_access_key_id, aws_secret_access_key, options)
        end
      end

      def connection
        self.class.connection
      end
    end
  end
end

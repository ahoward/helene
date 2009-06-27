module Helene
  module Sdb
    class Base
      class << Base
        def connections(&block)
          Sdb.connections(&block)
        end

        def connection
          Sdb.connection
        end
      end

      def connection
        self.class.connection
      end

    end
  end
end

module Helene
  module Sdb
    class Base
      class << Base
        def logger
          Helene.logger
        end

        def log(*args, &block)
          Helene.log(*args, &block)
        end
      end

      def logger
        Helene.logger
      end

      def log(*args, &block)
        Helene.log(*args, &block)
      end
    end
  end
end

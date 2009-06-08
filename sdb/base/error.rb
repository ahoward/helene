module Helene
  module Sdb
    class Base
      class Error < Helene::Error; end

      class << Base
        def error!(message)
          raise Error.new(message.to_s)
        end
      end

      def error!(message)
        self.class.error!(message)
      end
    end
  end
end

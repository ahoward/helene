module Helene
  module Sdb
    class Base
      module Transaction
        attr :id

        def call(*args, &block)
          return block.call() if id?
          @id = generate_id
          begin
            block.call()
          ensure
            @id = nil
          end
        end

        def id?
          defined?(@id) and @id
        end

        def id
          id? ? @id : generate_id
        end

        def generate_id
          UUID.timestamp_create().to_s
        end

        extend self
      end

      class << Base
        def transaction(&block)
          Transaction.call(&block)
        end
      end

      def transaction(&block)
        self.class.transaction.call(&block)
      end
    end
  end
end

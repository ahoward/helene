module Helene
  module Sdb
    class Base
      module Transaction
        attr_writer :id
        attr_writer :time

        def call(*args, &block)
          return block.call() if id?
          @id = generate_id
          @time = Time.now.utc
          begin
            block.call()
          ensure
            @id = @time = nil
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

        def time?
          defined?(@time) and @time
        end

        def time
          time? ? @time : Time.now.utc
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

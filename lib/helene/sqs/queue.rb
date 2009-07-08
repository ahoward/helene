module Helene
  module Sqs
    class Queue
      def self.interface
        Sqs.interface
      end
      
      def self.list(prefix = nil)
        interface.list_queues(prefix)
      end
    end
  end
end

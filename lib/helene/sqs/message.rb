module Helene
  module Sqs
    class Message
      def self.interface
        Sqs.interface
      end

      def initialize(queue, fields)
        @queue          = queue
        @id             = fields["MessageId"]
        @receipt_handle = fields["ReceiptHandle"]
        @body           = fields["Body"]
        @md5_of_body    = fields["MD5OfBody"]
      end
      
      attr_reader :id, :body
      
      def valid?
        MD5.md5(@body) == @md5_of_body
      end
      
      def interface
        self.class.interface
      end
      
      def delete
        @queue.require_url
        begin
          interface.delete_message(@queue.url, @receipt_handle)
          true
        rescue Exception
          false
        end
      end
      alias_method :destroy, :delete
      alias_method :remove,  :delete
    end
  end
end

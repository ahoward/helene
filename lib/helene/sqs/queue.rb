module Helene
  module Sqs
    class Queue
      class SQSError              < RuntimeError; end
      class QueueURLRequiredError < SQSError;     end
      
      def self.interface
        Sqs.interface
      end
      
      def self.list_urls(prefix = nil)
        interface.list_queues(prefix)
      end
      
      def self.find_url_by_name(name, queues = list_urls)
        queues.find { |url| url =~ %r{/#{Regexp.escape(name)}\z} }
      end
      
      def self.list(prefix = nil)
        list_urls(prefix).map { |url| new(url) }
      end
      
      def initialize(url_or_name)
        if url_or_name =~ %r{\Ahttps?://}
          @url  = url_or_name
          @name = interface.queue_name_by_url(url_or_name)
        else
          @name = url_or_name
          @url  = self.class.find_url_by_name(@name)
        end
      end
      
      attr_reader :name, :url
      
      def interface
        self.class.interface
      end
      
      def create(visibility_timeout = nil)
        @url = interface.create_queue(@name, visibility_timeout)
        true
      rescue Exception
        false
      end
      alias_method :build, :create
      
      def delete
        require_url
        begin
          interface.delete_queue(@url)
          @url = nil
          true
        rescue Exception
          false
        end
      end
      alias_method :destroy, :delete
      alias_method :remove,  :delete
      
      def attributes
        require_url
        begin
          interface.get_queue_attributes(@url)
        rescue Exception
          { }
        end
      end
      
      def approximate_number_of_messages
        if anom = attributes["ApproximateNumberOfMessages"]
          anom.to_i
        end
      end
      
      def visibility_timeout
        if vt = attributes["VisibilityTimeout"]
          vt.to_i
        end
      end
      
      def visibility_timeout=(new_timeout)
        require_url
        interface.set_queue_attributes(@url, "VisibilityTimeout", new_timeout)
      end
      alias_method :update_visibility_timeout, :visibility_timeout=
      
      def queue(message)
        require_url
        begin
          interface.send_message(@url, message)
          true
        rescue Exception
          false
        end
      end
      alias_method :q,            :queue
      alias_method :enqueue,      :queue
      alias_method :nq,           :queue
      alias_method :send_message, :queue
      
      def receive_messages(max_count = 10, visibility_timeout = nil)
        require_url
        begin
          interface.receive_message(@url, max_count, visibility_timeout).
                    map { |fields| Message.new(self, fields) }
        rescue Exception
          [ ]
        end
      end
      
      def dequeue(visibility_timeout = nil)
        receive_messages(1, visibility_timeout).first
      end
      alias_method :dq,              :dequeue
      alias_method :receive_message, :dequeue
      
      def require_url
        if @url.blank?
          raise QueueURLRequiredError, "A URL is required to delete this queue."
        end
      end
    end
    Q = Queue
  end
end

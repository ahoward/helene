module Helene
  module Sqs
    class Queue
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
      
      def create(default_visibility_timeout = nil)
        @url = interface.create_queue(@name, default_visibility_timeout)
      end
    end
  end
end

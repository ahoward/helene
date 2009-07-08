module Helene
  module Connectable
    def self.extended(aws_service)
      aws_service.class_eval <<-END_RUBY
      class ConnectionProxy < BlankSlate
        def method_missing(method, *args, &block)
          #{aws_service}.connections do |connection|
            connection.send(method, *args, &block)
          end
        end
      end
      END_RUBY
      aws_service.instance_variable_set(
        "@connections",
        ObjectPool.new(:size => 8) { aws_service.create_connection }
      )
    end
    
    def create_connection(*args)
      options           = args.extract_options!.to_options!
      access_key_id     = options.delete(:access_key_id)     ||
                          args.shift                         ||
                          Helene.access_key_id
      secret_access_key = options.delete(:secret_access_key) ||
                          args.shift                         ||
                          Helene.secret_access_key
      interface         = const_get(:Interface) rescue
                          RightAws.const_get("#{name[/\w+\z/]}Interface")
      interface.new(access_key_id, secret_access_key, options)
    end

    def connection
      @connection ||= const_get(:ConnectionProxy).new
    end
    alias_method :interface, :connection

    def connections(&block)
      block ? @connections.get(&block) : @connections
    end
  end
end

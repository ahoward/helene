module Rightscale
  class HttpConnection
    alias_method '__request__', 'request' unless instance_methods.include?('__request__')

    def request(request_params, &block)
      logger.debug{ "HttpConnection - request_params=#{ request_params.inspect }" }
      if((request = request_params[:request]))
        method = request.method
        path = request.path
        #body = (request.body.size > 42 ? (request.body[0,42] + '...') : request.body) if request.body
        body = request.body
        logger.debug{ "HttpConnection - request.method=#{ method.inspect }" }
        logger.debug{ "HttpConnection - request.path=#{ path.inspect }" }
        logger.debug{ "HttpConnection - request.body=#{ body.inspect }" }
      end
      response = __request__(request_params, &block)
    ensure
      if response
        code = response.code
        message = response.message
        #body = (response.body.size > 42 ? (response.body[0,42] + '...') : response.body) if response.body
        body = response.body
        logger.debug{ "HttpConnection - response.code=#{ code.inspect }" }
        logger.debug{ "HttpConnection - response.message=#{ message.inspect }" }
        logger.debug{ "HttpConnection - response.body=#{ body.inspect }" }
      end
    end

    Initialize = instance_method(:initialize)

    def initialize(*args, &block)
      Initialize.bind(self).call(*args, &block)
    ensure
      @logger = Helene.logger
    end
  end
end


RAILS_DEFAULT_LOGGER = Helene.logger unless defined?(RAILS_DEFAULT_LOGGER) ### WTF?

module Rightscale
  class HttpConnection
=begin
    params[:debug_output] = RAILS_ENV!='production' ? STDERR : nil

    alias_method '__start__', 'start' unless instance_methods.include?('__start__')

    def start(*args, &block)
      __start__(*args, &block)
    ensure
      debug_output = get_param(:debug_output)
      @http.instance_variable_set('@debug_output', debug_output) if debug_output
      #p @http.instance_variable_set(@debug_output, params[:debug_output])
      p @http.instance_variable_get('@debug_output')
    end
=end
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
  end
end

module Helene
  module Sdb
    class Interface < RightAws::RightAwsBase
      include RightAws
      
      include RightAwsBaseInterface

      DEFAULT_HOST               = 'sdb.amazonaws.com' unless defined?(DEFAULT_HOST)
      DEFAULT_PORT               = 443                 unless defined?(DEFAULT_PORT)
      DEFAULT_PROTOCOL           = 'https'             unless defined?(DEFAULT_PROTOCOL)
      API_VERSION                = '2007-11-07'        unless defined?(API_VERSION)
      DEFAULT_NIL_REPRESENTATION = 'nil'               unless defined?(DEFAULT_NIL_REPRESENTATION)

      @@bench = AwsBenchmarkingBlock.new
      def self.bench_xml; @@bench.xml;     end
      def self.bench_sdb; @@bench.service; end

      attr_reader :last_query_expression
      attr_reader :nil_rep
      alias_method 'nil_representation', 'nil_rep'

      def initialize(aws_access_key_id=nil, aws_secret_access_key=nil, params={})
        @nil_rep = params[:nil_representation] ? params[:nil_representation] : DEFAULT_NIL_REPRESENTATION
        params.delete(:nil_representation)
        params[:multi_thread] = true #unless params.has_key?(:multi_thread)
        init({ :name             => 'SDB', 
               :default_host     => ENV['SDB_URL'] ? URI.parse(ENV['SDB_URL']).host   : DEFAULT_HOST, 
               :default_port     => ENV['SDB_URL'] ? URI.parse(ENV['SDB_URL']).port   : DEFAULT_PORT, 
               :default_protocol => ENV['SDB_URL'] ? URI.parse(ENV['SDB_URL']).scheme : DEFAULT_PROTOCOL }, 
             aws_access_key_id     || ENV['AWS_ACCESS_KEY_ID'], 
             aws_secret_access_key || ENV['AWS_SECRET_ACCESS_KEY'], 
             params)
      end

      def generate_request(action, params={}) #:nodoc:
        # remove empty params from request
        params.delete_if {|key,value| value.nil? }
        #params_string  = params.to_a.collect{|key,val| key + "=#{CGI::escape(val.to_s)}" }.join("&")
        # prepare service data
        service = '/'
        service_hash = {"Action"         => action,
                        "AWSAccessKeyId" => @aws_access_key_id,
                        "Version"        => API_VERSION }
        service_hash.update(params)
        service_params = signed_service_params(@aws_secret_access_key, service_hash, :get, @params[:server], service)
        #
        # use POST method if the length of the query string is too large
        # see http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/MakingRESTRequests.html
        if service_params.size > 2000
          if signature_version == '2'
            # resign the request because HTTP verb is included into signature
            service_params = signed_service_params(@aws_secret_access_key, service_hash, :post, @params[:server], service)
          end
          request      = Net::HTTP::Post.new(service)
          request.body = service_params
          request['Content-Type'] = 'application/x-www-form-urlencoded'
        else
          request = Net::HTTP::Get.new("#{service}?#{service_params}")
        end
        # prepare output hash
        { :request  => request, 
          :server   => @params[:server],
          :port     => @params[:port],
          :protocol => @params[:protocol] }
      end

# TODO - need to dig much deeper into why this sometimes fails in MT
# conditions
#
      def request_info(request, parser)  #:nodoc:
        #thread = @params[:multi_thread] ? Thread.current : Thread.main
        thread = Thread.current
        thread[:sdb_connection] ||= Rightscale::HttpConnection.new(:exception => AwsError, :logger => @logger)
        e = nil
        42.times do
          begin
            return request_info_impl(thread[:sdb_connection], @@bench, request, parser)
          rescue Object => e
            raise unless e.class <= StandardError
            @logger.error{ e } rescue nil
            thread[:sdb_connection] = Rightscale::HttpConnection.new(:exception => AwsError, :logger => @logger)
            next
          end
        end
        raise(e || 'wtf')
      end

      def escape(value)
        if value
          value = value.to_s.gsub(/(['\\])/){ "\\#{$1}" }
          "'#{ value }'"
        end
      end
      
      def ruby_to_sdb(value)
        value.nil? ? @nil_rep : value
      end
      
      def sdb_to_ruby(value)
        value.eql?(@nil_rep) ? nil : value
      end

      def sdb_nil
        unless defined?(@sdb_nil)
          @sdb_nil = ruby_to_sdb(@nil_rep)
        end
        @sdb_nil
      end

      def ruby_nil
        unless defined?(@ruby_nil)
          @ruby_nil = sdb_to_ruby(sdb_nil)
        end
        @ruby_nil
      end

      def query_expression_from_array(params) #:nodoc:
        return '' if params.blank?
        query = params.shift.to_s
        query.gsub(/(\\)?(\?)/) do
          if $1 # if escaped '\?' is found - replace it by '?' without backslash
            "?"
          else  # well, if no backslash precedes '?' then replace it by next param from the list
            escape(params.shift)
          end
        end
      end

      def query_expression_from_hash(hash)
        return '' if hash.blank?
        expression = []
        hash.each do |key, value|
          expression << "#{key}=#{escape(value)}"
        end
        expression.join(' AND ')
      end

      def list_domains(max_number_of_domains = nil, next_token = nil )
        request_params = { 'MaxNumberOfDomains' => max_number_of_domains,
                           'NextToken'          => next_token }
        link   = generate_request("ListDomains", request_params)
        result = request_info(link, QSdbListDomainParser.new)
        # return result if no block given
        return result unless block_given?
        # loop if block if given
        begin
          # the block must return true if it wanna continue 
          break unless yield(result) && result[:next_token]
          # make new request
          request_params['NextToken'] = result[:next_token]
          link   = generate_request("ListDomains", request_params)
          result = request_info(link, QSdbListDomainParser.new)
        end while true
      rescue Exception
        on_exception
      end
      
      def create_domain(domain_name)
        link = generate_request("CreateDomain",
                                'DomainName' => domain_name)
        request_info(link, QSdbSimpleParser.new)
      rescue Exception
        on_exception
      end

      def delete_domain(domain_name)
        link = generate_request("DeleteDomain",
                                'DomainName' => domain_name)
        request_info(link, QSdbSimpleParser.new)
      rescue Exception
        on_exception
      end
      
      def put_attributes(domain_name, item_name, attributes, replace = false)
        params = { 'DomainName' => domain_name,
                   'ItemName'   => item_name }.merge(pack_put_attributes(attributes, :replace => replace))
        link = generate_request("PutAttributes", params)
        request_info( link, QSdbSimpleParser.new )
      rescue Exception
        on_exception
      end

      def pack_put_attributes(attributes, options)
        replace = (options.delete(:replace) || false)
        prefix = options.delete(:prefix)

        result = {}

        if attributes
          idx = 0
          attributes = attributes.inject({}){|h,k| h.update k=>nil} if attributes.is_a?(Array)
          attributes.each do |attribute, value|
            attribute = attribute.to_s

            if value.is_a?(Array)
              values = Array(value).flatten

              result["#{prefix}Attribute.#{idx}.Replace"] = 'true' if replace
              result["#{prefix}Attribute.#{idx}.Name"]  = attribute
              result["#{prefix}Attribute.#{idx}.Value"] = '[]'
              idx += 1

              values.each do |value|
                result["#{prefix}Attribute.#{idx}.Replace"] = 'true' if replace
                result["#{prefix}Attribute.#{idx}.Name"]  = attribute
                result["#{prefix}Attribute.#{idx}.Value"] = ruby_to_sdb(value)
                idx += 1
              end
            else
              result["#{prefix}Attribute.#{idx}.Replace"] = 'true' if replace
              result["#{prefix}Attribute.#{idx}.Name"] = attribute
              result["#{prefix}Attribute.#{idx}.Value"] = ruby_to_sdb(value)
              idx += 1
            end
          end
        end

        result
      end

      def batch_put_attributes(domain_name, items, replace = false)
        raise ArgumentError if items.empty?
        params = { 'DomainName' => domain_name }.merge(pack_batch_put_attributes(items, :replace => replace))
        link = generate_request("BatchPutAttributes", params)
        request_info( link, QSdbSimpleParser.new )
      rescue Exception
        on_exception
      end

      def pack_batch_put_attributes(items, options)
        result = {}
        index = -1
        items.each do |item_name, attributes|
          prefix = "Item.#{ index += 1 }."
          result.update pack_put_attributes(attributes, options.merge(:prefix => prefix))
          result.update "#{ prefix }ItemName" => item_name
        end
        result
      end
      
      def get_attributes(domain_name, item_name, attribute_name=nil)
        link = generate_request("GetAttributes", 'DomainName'    => domain_name,
                                                 'ItemName'      => item_name,
                                                 'AttributeName' => attribute_name )
        res = request_info(link, QSdbGetAttributesParser.new)
        res[:attributes].each_value do |values|
          values.collect! { |e| sdb_to_ruby(e) }
        end
        res
      rescue Exception
        on_exception
      end

      def delete_attributes(domain_name, item_name, attributes = {})
        params = { 'DomainName' => domain_name, 'ItemName' => item_name }.merge(pack_delete_attributes(attributes))
        link = generate_request("DeleteAttributes", params)
        request_info( link, QSdbSimpleParser.new )
      rescue Exception
        on_exception
      end

      def pack_delete_attributes(attributes, options = {})
        result = {}

        if attributes
          idx = 0
          attributes = attributes.inject({}){|h,k| h.update k=>nil} if attributes.is_a?(Array)
          attributes.each do |attribute, value|
            attribute = attribute.to_s

            if value.is_a?(Array)
              values = Array(value).flatten
              idx += 1 # skip [] marker value!
              values.each do |value|
                result["Attribute.#{idx}.Name"]  = attribute
                result["Attribute.#{idx}.Value"] = ruby_to_sdb(value)
                idx += 1
              end
            else
              result["Attribute.#{idx}.Name"] = attribute
              idx += 1
            end
          end
        end

        result
      end

      def delete_item(domain_name, item_name)
        params = { 'DomainName' => domain_name, 'ItemName' => item_name}
        link = generate_request("DeleteAttributes", params)
        request_info( link, QSdbSimpleParser.new )
      rescue Exception
        on_exception
      end
      
      def select(select_expression, next_token = nil)
        select_expression      = query_expression_from_array(select_expression) if select_expression.is_a?(Array)
        @last_query_expression = select_expression
        #
        request_params = { 'SelectExpression' => select_expression,
                           'NextToken'        => next_token }
        link   = generate_request("Select", request_params)
        result = select_response_to_ruby(request_info( link, QSdbSelectParser.new(self) ))
        return result unless block_given?
        # loop if block if given
        begin
          # the block must return true if it wanna continue
          break unless yield(result) && result[:next_token]
          # make new request
          request_params['NextToken'] = result[:next_token]
          link   = generate_request("Select", request_params)
          result = select_response_to_ruby(request_info( link, QSdbSelectParser.new(self) ))
        end while true
      rescue Exception
        on_exception
      end

      def select_response_to_ruby(response) #:nodoc:
      #return response
        response[:items].each_with_index do |item, idx|
          item.each do |key, attributes|
            attributes.keys.each do |name|
              values = attributes[name]
              array = values.delete('[]')
              attributes[name] =
                if array
                  values.map{|value| sdb_to_ruby(value)}
                else
                  sdb_to_ruby(values.first)
                end
            end
          end
        end
        response
      end

      class QSdbListDomainParser < RightAWSParser #:nodoc:
        def reset
          @result = { :domains => [] }
        end
        def tagend(name)
          case name
          when 'NextToken'  then @result[:next_token] =  @text
          when 'DomainName' then @result[:domains]    << @text
          when 'BoxUsage'   then @result[:box_usage]  =  @text
          when 'RequestId'  then @result[:request_id] =  @text
          end
        end
      end

      class QSdbSimpleParser < RightAWSParser #:nodoc:
        def reset
          @result = {}
        end
        def tagend(name)
          case name
          when 'BoxUsage'  then @result[:box_usage]  =  @text
          when 'RequestId' then @result[:request_id] =  @text
          end
        end
      end

      class QSdbGetAttributesParser < RightAWSParser #:nodoc:
        def reset
          @last_attribute_name = nil
          @result = { :attributes => {} }
        end
        def tagend(name)
          case name
          when 'Name'      then @last_attribute_name = @text
          when 'Value'     then (@result[:attributes][@last_attribute_name] ||= []) << @text
          when 'BoxUsage'  then @result[:box_usage]  =  @text
          when 'RequestId' then @result[:request_id] =  @text
          end
        end
      end

      class QSdbSelectParser < RightAWSParser #:nodoc:
        attr :interface
        def initialize(interface, *args, &block)
          @interface = interface
          super(*args, &block)
        end
        def reset
          @result = { :items => [] }
        end
        def tagend(name)
          case name
          when 'Name'
            case @xmlpath
            when 'SelectResponse/SelectResult/Item'
              @item = @text
              @result[:items] << { @item => {} }
            when 'SelectResponse/SelectResult/Item/Attribute'
              @attribute = @text
            end
          when 'RequestId' then @result[:request_id] = @text
          when 'BoxUsage'  then @result[:box_usage]  = @text
          when 'NextToken' then @result[:next_token] = @text
          when 'Value'
            (@result[:items].last[@item][@attribute] ||= []) << @text
#p @attribute => @text
=begin
            hash = @result[:items].last[@item]
            if @text == '[]'
              hash[@attribute] = hash.has_key?(@attribute) ? [hash[@attribute]] : []
            else
              if hash[@attribute].is_a?(Array)
                hash[@attribute] << @text
              else
                hash[@attribute] = @text
              end
            end
=end
#p @attribute => hash[@attribute]
          end
        end
      end

    end
  end
end


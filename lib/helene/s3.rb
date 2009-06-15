module Helene
  module S3
    class << S3
      def establish_connection(aws_access_key_id=Helene.aws_access_key_id, aws_secret_access_key=Helene.aws_secret_access_key, options={})
        options.to_options!
        @interface = RightAws::S3Interface.new(aws_access_key_id, aws_secret_access_key, options)
        raise Error, 'Connection to S3 is not established' unless @interface
        @s3g ||= RightAws::S3Generator.new(aws_access_key_id, aws_secret_access_key)
        raise Error, 'Connection to S3 is not established' unless @s3g
      ensure
        @interface.extend(ConnectionHack) if @interface
      end

      def interface
        @interface ||= nil
        establish_connection unless @interface
        @interface
      end
      alias_method 'connection', 'interface'

      def s3g
        @s3g ||= nil
        establish_connection unless @s3g
        @s3g
      end

# TODO - move this into right_aws_monkey_patches.rb
#
      module ConnectionHack
        class S3ListBucketParserHack < RightAws::RightAWSParser  # :nodoc:
          def reset
            @result      = []
            @service     = {}
            @current_key = {}

            class << @result
              attr_accessor :service
            end
            @result.service = @service
          end
          def tagstart(name, attributes)
            @current_key = {} if name == 'Contents'
          end
          def tagend(name)
            case name
                # service info
              when 'Name'        ; @service[:name]         = @text
              when 'Prefix'      ; @service[:prefix]       = @text
              when 'Marker'      ; @service[:marker]       = @text
              when 'MaxKeys'     ; @service[:max_keys]     = @text
              when 'Delimiter'   ; @service[:delimiter]    = @text
              when 'IsTruncated' ; @service[:is_truncated] = (@text =~ /false/ ? false : true)
                # key data
              when 'Key'         ; @current_key[:key]                = @text
              when 'LastModified'; @current_key[:last_modified]      = @text
              when 'ETag'        ; @current_key[:e_tag]              = @text
              when 'Size'        ; @current_key[:size]               = @text.to_i
              when 'StorageClass'; @current_key[:storage_class]      = @text
              when 'ID'          ; @current_key[:owner_id]           = @text
              when 'DisplayName' ; @current_key[:owner_display_name] = @text
              when 'Contents'    ; @current_key[:service]            = @service;  @result << @current_key
            end
          end
        end

        def list_bucket(bucket, options={}, headers={})
          bucket  += '?'+options.map{|k, v| "#{k.to_s}=#{CGI::escape v.to_s}"}.join('&') unless options.blank?
          req_hash = generate_rest_request('GET', headers.merge(:url=>bucket))
          request_info(req_hash, S3ListBucketParserHack.new(:logger => @logger))
        rescue
          on_exception
        end
      end

      load 'helene/s3/bucket.rb'
    end
  end
end

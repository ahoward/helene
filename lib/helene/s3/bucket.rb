module Helene
  module S3
    class Bucket
      class << Bucket
        def interface
          S3.interface
        end

        def list(&block)
          list = []
          interface.list_all_my_buckets.map! do |entry|
            owner = Owner.new(entry[:owner_id], entry[:owner_display_name])
            bucket = allocate
            name = entry[:name]
            creation_date = entry[:creation_date]
            options = {:interface => interface, :owner => owner, :creation_date => creation_date}
            bucket.send(:initialize, name, options)
            block ? block.all(bucket) : list.push(bucket)
          end
          block ? nil : list
        end
        alias_method 'buckets', 'list'

        def create(name, options = {})
          options.to_options!
          headers = options.delete(:headers) || {}
          interface.create_bucket(name, headers)
          new(name)
        end

        def new(name, options = {})
          result = S3.interface.list_bucket(name.to_s)
          service = result.service
          owner = Owner.new(service[:owner_id], service[:owner_display_name])
          bucket = allocate
          name = service[:name]
          options[:interface] || S3.interface
          options[:owner] ||= owner
          options[:creation_date] ||= service[:creation_date]
          bucket.send(:initialize, name, options)
          owner, grantees = Grantee.owner_and_grantees(bucket)
          bucket.owner = owner
          bucket
        end
        alias_method 'for', 'new'

        def url(*args)
          options = args.extract_options!.to_options!
          options.to_options!
          expires = options[:expires] || 24.hours
          headers = options.delete(:headers) || {}
          case args.shift.to_s
            when '', 'list'
              interface.list_all_my_buckets_link(expires, headers)
            when 'create'
              bucket = args.shift.to_s
              interface.create_bucket_link(bucket, expires, headers)
            when 'delete'
              bucket = args.shift.to_s
              interface.delete_bucket_link(bucket, expires, headers)
          end
        end
        alias_method 'url_for', 'url'

        def delete(bucket, options ={})
          options.to_options!
          force = options.delete(:force)
          name = bucket.is_a?(Bucket) ? bucket.name : bucket.to_s
          force ? interface.force_delete_bucket(name) : interface.delete_bucket(name)
        end
      end

      attr_accessor :name
      attr_accessor :interface
      attr_accessor :owner
      attr_accessor :creation_date
      attr :prefix

      def initialize(name, *args)
        options = args.extract_options!.to_options!
        @name  = name.to_s
        @interface = options[:interface] || S3.interface
        @owner = options[:owner]
        @creation_date = options[:creation_date]
        @prefix = cleanpath(options[:prefix]) if options[:prefix]
        if @creation_date && !@creation_date.is_a?(Time)
          @creation_date = Time.parse(@creation_date)
        end
      end

      def prefix= *prefixes
        @prefix = cleanpath(*prefixes)
      end

      def to_s
        @name.to_s
      end

      def == other
        name == other.name and prefix == other.prefix
      end

      def cleanpath(*paths)
        path = File.join(*paths.flatten.compact)
        path = path.to_s.strip
        path.sub! %r|^[./]+|, ''
        path.sub! %r|/*$|, '/'
        path.squeeze! '/'
        path
      end

      def prefixed(path, &block)
        path = path.to_s
        absolute = path =~ %r|^/|
        if absolute
          path[1..-1]
        else
          return scoping(path, &block) if block
          @prefix ? File.join(@prefix, path) : path
        end
      end

      def scoping(suffix, &block)
        old = @prefix
        @prefix = cleanpath(@prefix, suffix)
        block.call
      ensure
        @prefix = old
      end
      alias_method 'suffixing', 'scoping'

      def / suffix
        bucket = clone
        bucket.prefix = cleanpath(@prefix, suffix)
        bucket
      end

      def put(data, *args, &block)
        options = args.extract_options!.to_options!

        meta = options.delete(:meta) || {}
        perms = options.delete(:perms)
        headers = options.delete(:headers) || {}

        io_for(data) do |io|
          path = args.shift || path_for(io)
          key = key_for(path, io, meta)
          headers = headers_for(path, headers)
          key.put(io, perms, headers)
          key
        end
      end

      def get(path, *args, &block)
        options = args.extract_options!.to_options!
        headers = options.delete(:headers) || {}
        key = key_for(path)
        key.get(headers)
      end

      def io_for(arg)
        return(arg.respond_to?(:read) ? yield(arg) : open(arg.to_s){|io| yield(io)})
      end

      def path_for(arg)
        path = nil
        %w[ path pathname filename ].each do |msg|
          if arg.respond_to?(msg)
            path = File.basename(arg.send(msg).to_s)
            break path
          end
        end
        raise Errror, "no path from #{ arg.inspect }" if path.blank?
        cleanpath(path)
      end

      def key_for(arg, io = nil, meta = {})
        return arg if arg.is_a?(Key)
        Key.create(self, prefixed(arg.to_s), io, meta)
      end

      def headers_for(path, headers = {})
        headers = HashWithIndifferentAccess.new(headers)
        content_type = (
          headers.delete(:content_type) ||
          headers.delete(:Content_Type) ||
          headers.delete(:ContentType) ||
          content_type_for(path)
        )
        headers.merge!('Content-Type' => content_type) if content_type
        headers
      end

      def content_type_for(basename)
        Util.content_type_for(basename)
      end

      def url(*args)
        options = args.extract_options!.to_options!
        options.to_options!
        method = options.delete(:method) || args.shift.to_s
        path = options.delete(:path) || args.shift
        data = options.delete(:data) || args.shift
        expires = options.delete(:expires) || 24.hours
        query = options.delete(:query)
        headers = options.delete(:headers) || {}

        case method.to_s
          when '', 'list'
            (query ||= {})[:prefix] ||= prefix if prefix
            interface.list_bucket_link(name, query, expires, headers)
          when 'put'
            interface.put_link(name, prefixed(path), data, expires, headers)
          when 'get'
            interface.get_link(name, prefixed(path), expires, headers)
          when 'head'
            interface.head_link(name, prefixed(path), expires, headers)
          when 'delete'
            interface.delete_link(name, prefixed(path), expires, headers)
          when 'get_acl'
            interface.get_acl_link(name, prefixed(path), headers)
          when 'put_acl'
            interface.put_acl_link(name, prefixed(path), headers)
          when 'get_bucket_acl'
            interface.get_bucket_acl_link(name, headers)
          when 'put_bucket_acl'
            interface.put_bucket_acl_link(name, headers)
          else
            raise ArgumentError, method.inspect
        end
      end
      alias_method 'url_for', 'url'
      
      def clear(options = {})
        options.to_options!
        prefix = options[:prefix] || @prefix
        if prefix
          @interface.delete_folder(@name, prefix)
        else
          @interface.clear_bucket(name)
        end
      end

      def keys(options={}, &block)
        options.to_options!
        options[:prefix] ||= prefix
        options.delete(:service)
        keys_and_service(options, &block)
      end
      alias_method 'list', 'keys'

      def ls(options = {}, &block)
        names = []
        keys do |key|
          block ? block.call(key.name) : names.push(key.name)
        end
        block ? nil : names
      end

    # TODO - refactor messiness with service
    #
      def keys_and_service(options={}, &block)
        options.to_options!
        options[:prefix] ||= prefix
        head = options.delete(:head)
        wants_service = options.delete(:service)
        service = {}
        hash = {}
        keys = []
        @interface.incrementally_list_bucket(@name, options.stringify_keys) do |hash|
          hash[:contents].each do |entry|
            owner = Owner.new(entry[:owner_id], entry[:owner_display_name])
            key = Key.new(self, entry[:key], nil, {}, {}, entry[:last_modified], entry[:e_tag], entry[:size], entry[:storage_class], owner)
            key.head if head
            block ? block.call(key) : keys.push(key)
          end
        end
        if wants_service
          hash.each_key do |key|
            service[key] = hash[key] unless (key == :contents || key == :common_prefixes)
          end
          [keys, service]
        else
          block ? nil : keys
        end
      end

      def key(path, options={}, &block)
        options.to_options!
        options[:prefix] ||= prefixed(path.to_s)
        keys(options).first
      end
      alias_method '[]', 'key'

    # TODO - refactor, possibly place in key.rb
    #
      def find_or_create_key_by_absolute_path(path, options = {})
        path = path.to_s
        options.to_options!
        head = options.has_key?(:head) ? options.delete(:head) : true
        key = nil
        keys(:prefix => path, :head => head).each do |candidate|
          break(key = candidate) if candidate.name == path
        end
        key ||= Key.create(self, path)
      end

      def has_key?(path)
        find_or_create_key_by_absolute_path(prefixed(path)).exists?
      end

      def rename_key(src, dst)
        src = Key.create(self, prefixed(src.to_s)) unless src.is_a?(Key)
        src.rename(prefixed(dst))
        src
      end
      alias_method 'rename', 'rename_key'

      def copy_key(src, dst)
        src = Key.create(self, prefixed(src.to_s)) unless src.is_a?(Key)
        src.copy(prefixed(dst))
      end
      alias_method 'cp', 'copy_key'
      alias_method 'copy', 'copy_key'
      
      def move_key(src, dst)
        src = Key.create(self, prefixed(src.to_s)) unless src.is_a?(Key)
        src.move(prefixed(dst))
      end
      alias_method 'mv', 'move_key'
      alias_method 'move', 'move_key'

      def location # '' or 'EU'
        @location ||= @interface.bucket_location(name)
      end
      
      def logging_info
        @interface.get_logging_parse(:bucket => @name)
      end
      
      def enable_logging(params)
        AwsUtils.mandatory_arguments([:targetbucket, :targetprefix], params)
        AwsUtils.allow_only([:targetbucket, :targetprefix], params)
        xmldoc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><BucketLoggingStatus xmlns=\"http://doc.s3.amazonaws.com/2006-03-01\"><LoggingEnabled><TargetBucket>#{params[:targetbucket]}</TargetBucket><TargetPrefix>#{params[:targetprefix]}</TargetPrefix></LoggingEnabled></BucketLoggingStatus>"
        @interface.put_logging(:bucket => @name, :xmldoc => xmldoc)
      end
      
      def disable_logging
        xmldoc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><BucketLoggingStatus xmlns=\"http://doc.s3.amazonaws.com/2006-03-01\"></BucketLoggingStatus>"
        @interface.put_logging(:bucket => @name, :xmldoc => xmldoc)
      end

      def grantees
        Grantee::grantees(self)
      end
    end
  end
end

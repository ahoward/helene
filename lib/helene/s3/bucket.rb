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

        def ls(&block)
          result = []
          list.each do |bucket|
            block ? block.call(bucket.name) : result.push(bucket.name)
          end
          block ? nil : result
        end

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
        alias_method 'destroy', 'delete'
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
        @prefix = Key.clean(options[:prefix]) if options[:prefix]
        if @creation_date && !@creation_date.is_a?(Time)
          @creation_date = Time.parse(@creation_date)
        end
      end

      def bucket
        self
      end

      def prefix= *prefixes
        @prefix = Key.clean(*prefixes)
      end

      def to_s
        @name.to_s
      end

      def == other
        name == other.name and prefix == other.prefix
      end

      def prefixed_key_for(key)
        return key if key.is_a?(Key)
        Key.new(key.to_s, :prefix => @prefix)
      end

      def prefixed_key_from(key)
        return key if key.is_a?(Key)
        key = key.to_s
        key[%r/\A#{ Regexp.escape(@prefix) }/] = '' if @prefix
        Key.new(key, :prefix => @prefix)
      end

      def scoping(suffix, &block)
        old = @prefix
        @prefix = Key.clean(@prefix, suffix)
        block.call
      ensure
        @prefix = old
      end
      alias_method 'suffixing', 'scoping'
      alias_method 'prefixed', 'scoping'

      def / suffix
        bucket = clone
        bucket.prefix = Key.clean(@prefix, suffix)
        bucket
      end

      def put(arg, *args, &block)
        options = args.extract_options!.to_options!

        meta = options.delete(:meta) || {}
        perms = options.delete(:perms)
        headers = options.delete(:headers) || {}

        data_for(arg) do |data|
          path = args.shift || path_for(data)
#p :data=>data
#p :path=>path
#abort
          object = object_for(path, data, meta)
          headers = headers_for(path, headers)
          object.put(data, perms, headers)
          object
        end
      end

      def put_data(arg, *args, &block)
        if arg.is_a?(Pathname)
          arg.open{|fd| put(fd, *args, &block)}
        else
          put(arg, *args, &block)
        end
      end
      alias_method 'write', 'put_data'

      def put_path(path, *args, &block)
        put(Pathname.new(path.to_s), *args, &block)
      end
      alias_method 'put_pathname', 'put_path'

      def get(path, *args, &block)
        options = args.extract_options!.to_options!
        headers = options.delete(:headers) || {}
        object = object_for(path)
        object.get(headers)
      end

      def data(path, *args, &block)
        get(path, *args, &block).data
      end
      alias_method 'read', 'data'
      alias_method 'get_data', 'data'

      def data_for(arg)
        if arg.is_a?(Pathname)
          open(arg.to_s){|io| return yield(io)}
        end
        if arg.respond_to?(:read)
          return yield(arg)
        end
        return yield(arg.to_s)
      end

      def path_for(arg)
        return arg.to_s if arg.is_a?(Pathname)
        path = nil
        %w[ path pathname filename ].each do |msg|
          if arg.respond_to?(msg)
            path = File.basename(arg.send(msg).to_s)
            break path
          end
        end
        raise Error, "no path from #{ arg.inspect }" if path.blank?
        Key.clean(path)
      end

      def object_for(arg, io = nil, meta = {})
        return arg if arg.is_a?(Object)
        Object.new(bucket, prefixed_key_for(arg), :data => io, :meta => meta)
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
            interface.put_link(name, prefixed_key_for(path), data, expires, headers)
          when 'get'
            interface.get_link(name, prefixed_key_for(path), expires, headers)
          when 'head'
            interface.head_link(name, prefixed_key_for(path), expires, headers)
          when 'delete'
            interface.delete_link(name, prefixed_key_for(path), expires, headers)
          when 'get_acl'
            interface.get_acl_link(name, prefixed_key_for(path), headers)
          when 'put_acl'
            interface.put_acl_link(name, prefixed_key_for(path), headers)
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

      def destroy(options = {})
        Bucket.destroy(bucket, options)
      end

      def objects(options={}, &block)
        options.to_options!
        options[:prefix] ||= prefix
        options.delete(:service)
        each_object(options, &block)
      end
      alias_method 'list', 'objects'

      def ls(options = {}, &block)
        names = []
        objects do |object|
          block ? block.call(object.name) : names.push(object.name)
        end
        block ? nil : names
      end

    # TODO - clean up old cruft with 'service' option
    #
      def each_object(options={}, &block)
        options.to_options!
        options[:prefix] ||= prefix
        head = options.delete(:head)
        wants_service = options.delete(:service)
        service = {}
        hash = {}
        objects = []
        @interface.incrementally_list_bucket(@name, options.stringify_keys) do |hash|
          hash[:contents].each do |entry|
            owner = Owner.new(entry[:owner_id], entry[:owner_display_name])
            object = 
              Object.new(
                :bucket => bucket,
                :key => prefixed_key_from(entry[:key]),
                :last_modified => entry[:last_modified],
                :e_tag => entry[:e_tag],
                :size => entry[:size],
                :storage_class => entry[:storage_class],
                :owner => owner
              )
            object.head if head
            block ? block.call(object) : objects.push(object)
          end
        end
        if wants_service
          hash.each_key do |key|
            service[key] = hash[key] unless (key == :contents || key == :common_prefixes)
          end
          [objects, service]
        else
          block ? nil : objects
        end
      end

      def object(path, options={}, &block)
        options.to_options!
        options[:prefix] ||= prefixed_key_for(path)
        objects(options).first
      end
      alias_method '[]', 'object'

    # TODO - refactor, possibly place in object.rb
    #
      def find_or_create_object_by_absolute_path(path, options = {})
        path = path.to_s
        options.to_options!
        head = options.has_key?(:head) ? options.delete(:head) : true
        object = nil
        objects(:prefix => path, :head => head).each do |candidate|
          break(object = candidate) if candidate.name == path
        end
        object ||= Object.new(bucket, path)
      end

      def has_key?(path)
        find_or_create_object_by_absolute_path(prefixed_key_for(path)).exists?
      end

      def rename_object(src, dst)
        src = Object.new(bucket, prefixed_key_for(src)) unless src.is_a?(Object)
        src.rename(prefixed_key_for(dst))
        src
      end
      alias_method 'rename', 'rename_object'

      def copy_object(src, dst)
        src = Object.new(bucket, prefixed_key_for(src)) unless src.is_a?(Object)
        src.copy(prefixed_key_for(dst))
      end
      alias_method 'cp', 'copy_object'
      alias_method 'copy', 'copy_object'
      
      def move_object(src, dst)
        src = Object.new(bucket, prefixed_key_for(src)) unless src.is_a?(Object)
        src.move(prefixed_key_for(dst))
      end
      alias_method 'mv', 'move_object'
      alias_method 'move', 'move_object'

      def location # '' or 'EU'
        @location ||= @interface.bucket_location(name)
      end
      
    # TODO - totally untested
    #
      def logging_info
        @interface.get_logging_parse(:bucket => @name)
      end
      
    # TODO - totally untested
    #
      def enable_logging(params)
        AwsUtils.mandatory_arguments([:targetbucket, :targetprefix], params)
        AwsUtils.allow_only([:targetbucket, :targetprefix], params)
        xmldoc = 
          "
            <?xml version=\"1.0\" encoding=\"UTF-8\"?>
              <BucketLoggingStatus xmlns=\"http://doc.s3.amazonaws.com/2006-03-01\">
              <LoggingEnabled>
                <TargetBucket>#{params[:targetbucket]}</TargetBucket>
                <TargetPrefix>#{params[:targetprefix]}</TargetPrefix>
              </LoggingEnabled></BucketLoggingStatus>
          "
        @interface.put_logging(:bucket => @name, :xmldoc => xmldoc)
      end
      
    # TODO - totally untested
    #
      def disable_logging
        xmldoc =
          "
            <?xml version=\"1.0\" encoding=\"UTF-8\"?>
              <BucketLoggingStatus xmlns=\"http://doc.s3.amazonaws.com/2006-03-01\">
              </BucketLoggingStatus>
          "
        @interface.put_logging(:bucket => @name, :xmldoc => xmldoc)
      end

    # TODO - totally untested
    #
      def grantees
        Grantee::grantees(self)
      end
    end
  end
end

module Helene
  module S3
    class Object
      class << Object
        MetaHeader = 'x-amz-meta'
        MetaHeaderPrefix = MetaHeader + '-'
        ACLHeader = 'x-amz-acl'

        def partition_into_meta_headers(headers) #:nodoc:
          hash = headers.dup
          meta = {}
          hash.each do |key, value|
            if key[%r/^#{ MetaHeaderPrefix }/]
              meta[key.gsub(MetaHeaderPrefix, '')] = value
              hash.delete(key)
            end
          end
          [hash, meta]
        end

        def meta_prefixed(meta_headers, prefix=MetaHeaderPrefix)
          meta = {}
          meta_headers.each do |meta_header, value|
            if meta_header[%r/#{prefix}/]
              meta[meta_header] = value
            else
              meta["#{ MetaHeaderPrefix }#{meta_header}"] = value
            end
          end
          meta
        end
      end

      attr_accessor :bucket
      attr_accessor :name
      attr_accessor :last_modified
      attr_accessor :e_tag
      attr_accessor :size
      attr_accessor :storage_class
      attr_accessor :owner
      attr_accessor :headers
      attr_accessor :meta_headers
      attr_writer   :data
      
      # def initialize(bucket, name, data=nil, headers={}, meta_headers={}, last_modified=nil, e_tag=nil, size=nil, storage_class=nil, owner=nil)

      def initialize(*args)
        options = args.extract_options!.to_options!
        @bucket = args.shift || options[:bucket] 
        @name = args.shift || options[:name] || options[:key]
        @data = args.shift || options[:data]

        @e_tag         = options[:e_tag]
        @storage_class = options[:storage_class]
        @owner         = options[:owner]
        @last_modified = options[:last_modified]
        @size          = options[:size]
        @headers       = options[:headers]||{}
        @meta_headers  = options[:meta_headers]||options[:meta]||{}
         
        if @last_modified && !@last_modified.is_a?(Time) 
          @last_modified = Time.parse(@last_modified)
        end

        @size = Float(@size).to_i unless @size.nil?

        @headers, meta_headers = Object.partition_into_meta_headers(@headers)

        @meta_headers.merge!(meta_headers)
      end

      def url(*args)
        options = args.extract_options!.to_options!
        options.to_options!
        expires = options.delete(:expires) || 24.hours
        headers = options.delete(:headers) || {}
        case args.shift.to_s
          when '', 'get'
            bucket.interface.get_link(bucket, name.to_s, expires, headers)
        end
      end
      alias_method :url_for, :url
      
      def to_s
        @name.to_s
      end
      
      def data
        get if !@data and exists?
        @data
      end
      
      def get(headers={})
        response = @bucket.interface.get(@bucket.name, @name, headers)
        @data    = response[:object]
        @headers, @meta_headers = Object.partition_into_meta_headers(response[:headers])
        refresh(false)
        self
      end
      
      def put(data=nil, perms=nil, headers={})
        headers[ACLHeader] = perms if perms
        @data = data || @data
        meta  = Object.meta_prefixed(@meta_headers)
        @bucket.interface.put(@bucket.name, @name, @data, meta.merge(headers))
      end
      
      def rename(new_name)
        @bucket.interface.rename(@bucket.name, @name, new_name)
        @name = new_name
      end
      
      def copy(new_key_or_name)
        new_key_or_name = Object.create(@bucket, new_key_or_name.to_s) unless new_key_or_name.is_a?(Object)
        @bucket.interface.copy(@bucket.name, @name, new_key_or_name.bucket.name, new_key_or_name.name)
        new_key_or_name
      end

      def move(new_key_or_name)
        new_key_or_name = Object.create(@bucket, new_key_or_name.to_s) unless new_key_or_name.is_a?(Object)
        @bucket.interface.move(@bucket.name, @name, new_key_or_name.bucket.name, new_key_or_name.name)
        new_key_or_name
      end
      
      def refresh(head=true)
        new_key        = @bucket.find_or_create_object_by_absolute_path(name)
        @last_modified = new_key.last_modified
        @e_tag         = new_key.e_tag
        @size          = new_key.size
        @storage_class = new_key.storage_class
        @owner         = new_key.owner
        if @last_modified
          self.head
          true
        else
          @headers = @meta_headers = {}
          false
        end
      end

      def head
        @headers, @meta_headers = Object.partition_into_meta_headers(@bucket.interface.head(@bucket, @name))
        true
      end
      
      def reload_meta
        @meta_headers = Object.partition_into_meta_headers(@bucket.interface.head(@bucket, @name)).last
      end
      
      def save_meta(meta_headers)
        meta = Object.meta_prefixed(meta_headers)
        @bucket.interface.copy(@bucket.name, @name, @bucket.name, @name, :replace, meta)
        @meta_headers = Object.partition_into_meta_headers(meta).last
      end
 
      def exists?
        @bucket.find_or_create_object_by_absolute_path(name).last_modified ? true : false
      end

      
      def delete
        raise 'Object name must be specified.' if @name.blank?
        @bucket.interface.delete(@bucket, @name) 
      end
      
      def grantees
        Grantee::grantees(self)
      end
    end
  end
end

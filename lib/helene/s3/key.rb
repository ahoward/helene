module Helene
  module S3
    class Key
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

      alias_method 'url_for', 'url'
      attr_reader   :bucket,  :name, :last_modified, :e_tag, :size, :storage_class, :owner
      attr_accessor :headers, :meta_headers
      attr_writer   :data

      def self.split_meta(headers) #:nodoc:
        hash = headers.dup
        meta = {}
        hash.each do |key, value|
          if key[%r/^x-amz-meta-/]
            meta[key.gsub('x-amz-meta-', '')] = value
            hash.delete(key)
          end
        end
        [hash, meta]
      end
      
      def self.add_meta_prefix(meta_headers, prefix='x-amz-meta-')
        meta = {}
        meta_headers.each do |meta_header, value|
          if meta_header[/#{prefix}/]
            meta[meta_header] = value
          else
            meta["x-amz-meta-#{meta_header}"] = value
          end
        end
        meta
      end

      def self.create(bucket, name, data=nil, meta_headers={})
        new(bucket, name, data, {}, meta_headers)
      end
      
      def initialize(bucket, name, data=nil, headers={}, meta_headers={}, 
                     last_modified=nil, e_tag=nil, size=nil, storage_class=nil, owner=nil)
        raise 'Bucket must be a Bucket instance.' unless bucket.is_a?(Bucket)
        @bucket        = bucket
        @name          = name
        @data          = data
        @e_tag         = e_tag
        @size          = size.to_i
        @storage_class = storage_class
        @owner         = owner
        @last_modified = last_modified
        if @last_modified && !@last_modified.is_a?(Time) 
          @last_modified = Time.parse(@last_modified)
        end
        @headers, @meta_headers = self.class.split_meta(headers)
        @meta_headers.merge!(meta_headers)
      end
      
      def to_s
        @name.to_s
      end
      
      def full_name(separator='/')
        "#{@bucket.to_s}#{separator}#{@name}"
      end
        
      def public_link
        params = @bucket.interface.params
        "#{params[:protocol]}://#{params[:server]}:#{params[:port]}/#{full_name('/')}"
      end
         
      def data
        get if !@data and exists?
        @data
      end
      
      def get(headers={})
        response = @bucket.interface.get(@bucket.name, @name, headers)
        @data    = response[:object]
        @headers, @meta_headers = self.class.split_meta(response[:headers])
        refresh(false)
        @data
      end
      
      def put(data=nil, perms=nil, headers={})
        headers['x-amz-acl'] = perms if perms
        @data = data || @data
        meta  = self.class.add_meta_prefix(@meta_headers)
        @bucket.interface.put(@bucket.name, @name, @data, meta.merge(headers))
      end
      
      def rename(new_name)
        @bucket.interface.rename(@bucket.name, @name, new_name)
        @name = new_name
      end
      
      def copy(new_key_or_name)
        new_key_or_name = Key.create(@bucket, new_key_or_name.to_s) unless new_key_or_name.is_a?(Key)
        @bucket.interface.copy(@bucket.name, @name, new_key_or_name.bucket.name, new_key_or_name.name)
        new_key_or_name
      end

      def move(new_key_or_name)
        new_key_or_name = Key.create(@bucket, new_key_or_name.to_s) unless new_key_or_name.is_a?(Key)
        @bucket.interface.move(@bucket.name, @name, new_key_or_name.bucket.name, new_key_or_name.name)
        new_key_or_name
      end
      
      def refresh(head=true)
        new_key        = @bucket.find_or_create_key_by_absolute_path(name)
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
        @headers, @meta_headers = self.class.split_meta(@bucket.interface.head(@bucket, @name))
        true
      end
      
      def reload_meta
        @meta_headers = self.class.split_meta(@bucket.interface.head(@bucket, @name)).last
      end
      
      def save_meta(meta_headers)
        meta = self.class.add_meta_prefix(meta_headers)
        @bucket.interface.copy(@bucket.name, @name, @bucket.name, @name, :replace, meta)
        @meta_headers = self.class.split_meta(meta)[1]
      end
 
      def exists?
        @bucket.find_or_create_key_by_absolute_path(name).last_modified ? true : false
      end

      
      def delete
        raise 'Key name must be specified.' if @name.blank?
        @bucket.interface.delete(@bucket, @name) 
      end
      
      def grantees
        Grantee::grantees(self)
      end
    end
  end
end

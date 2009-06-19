module Helene
  module S3
    class Bucket
      attr_reader :s3, :name, :owner, :creation_date
      
      def self.create(s3, name, create=false, perms=nil, headers={}) 
        s3.bucket(name, create, perms, headers)
      end

      def initialize(s3, name, creation_date=nil, owner=nil)
        @s3    = s3
        @name  = name
        @owner = owner
        @creation_date = creation_date
        if @creation_date && !@creation_date.is_a?(Time)
          @creation_date = Time.parse(@creation_date)
        end
      end
      
      def to_s
        @name.to_s
      end
      alias_method :full_name, :to_s
      
      def public_link
        params = @s3.interface.params
        "#{params[:protocol]}://#{params[:server]}:#{params[:port]}/#{full_name}"
      end
      
      def location
        @location ||= @s3.interface.bucket_location(@name)
      end
      
      def logging_info
        @s3.interface.get_logging_parse(:bucket => @name)
      end
      
      def enable_logging(params)
        AwsUtils.mandatory_arguments([:targetbucket, :targetprefix], params)
        AwsUtils.allow_only([:targetbucket, :targetprefix], params)
        xmldoc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><BucketLoggingStatus xmlns=\"http://doc.s3.amazonaws.com/2006-03-01\"><LoggingEnabled><TargetBucket>#{params[:targetbucket]}</TargetBucket><TargetPrefix>#{params[:targetprefix]}</TargetPrefix></LoggingEnabled></BucketLoggingStatus>"
        @s3.interface.put_logging(:bucket => @name, :xmldoc => xmldoc)
      end
      
      def disable_logging
        xmldoc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><BucketLoggingStatus xmlns=\"http://doc.s3.amazonaws.com/2006-03-01\"></BucketLoggingStatus>"
        @s3.interface.put_logging(:bucket => @name, :xmldoc => xmldoc)
      end

      def keys(options={}, head=false)
        keys_and_service(options, head)[0]
      end

      def keys_and_service(options={}, head=false)
        opt = {}; options.each{ |key, value| opt[key.to_s] = value }
        service_data = {}
        thislist = {}
        list = []
        @s3.interface.incrementally_list_bucket(@name, opt) do |thislist|
          thislist[:contents].each do |entry|
            owner = Owner.new(entry[:owner_id], entry[:owner_display_name])
            key = Key.new(self, entry[:key], nil, {}, {}, entry[:last_modified], entry[:e_tag], entry[:size], entry[:storage_class], owner)
            key.head if head
            list << key
          end
        end
        thislist.each_key do |key|
          service_data[key] = thislist[key] unless (key == :contents || key == :common_prefixes)
        end
        [list, service_data]
      end

      def key(key_name, head=false)
        raise 'Key name can not be empty.' if key_name.blank?
        key_instance = nil
          # if this key exists - find it ....
        keys({'prefix'=>key_name}, head).each do |key|
          if key.name == key_name.to_s
            key_instance = key
            break
          end
        end
          # .... else this key is unknown
        unless key_instance
          key_instance = Key.create(self, key_name.to_s)
        end
        key_instance
      end
      
      def put(key, data=nil, meta_headers={}, perms=nil, headers={})
        key = Key.create(self, key.to_s, data, meta_headers) unless key.is_a?(Key) 
        key.put(data, perms, headers)
      end

      def get(key, headers={})
        key = Key.create(self, key.to_s) unless key.is_a?(Key)
        key.get(headers)
      end

      def rename_key(old_key_or_name, new_name)
        old_key_or_name = Key.create(self, old_key_or_name.to_s) unless old_key_or_name.is_a?(Key)
        old_key_or_name.rename(new_name)
        old_key_or_name
      end

      def copy_key(old_key_or_name, new_key_or_name)
        old_key_or_name = Key.create(self, old_key_or_name.to_s) unless old_key_or_name.is_a?(Key)
        old_key_or_name.copy(new_key_or_name)
      end
      
      def move_key(old_key_or_name, new_key_or_name)
        old_key_or_name = Key.create(self, old_key_or_name.to_s) unless old_key_or_name.is_a?(Key)
        old_key_or_name.move(new_key_or_name)
      end
      
      def clear
        @s3.interface.clear_bucket(@name)  
      end

      def delete_folder(folder, separator='/')
        @s3.interface.delete_folder(@name, folder, separator)
      end
      
      def delete(force=false)
        force ? @s3.interface.force_delete_bucket(@name) : @s3.interface.delete_bucket(@name)
      end

      def grantees
        Grantee::grantees(self)
      end
    end
  end
end

__END__
module Helene
  module S3
    class Bucket < RightAws::S3::Bucket
      Bucket.const_set(:Owner, RightAws::S3::Owner)
      # Bucket.const_set(:Key, RightAws::S3::Key)
      Bucket.const_set(:Grantee, RightAws::S3::Grantee)
      Bucket.const_set(:S3Generator, RightAws::S3Generator)

      class Key < RightAws::S3::Key
      end

      class Error < Helene::Error; end

    # class methods
    #
      class << Bucket
        def list
          S3.interface.list_all_my_buckets.map! do |entry|
            owner = Owner.new(entry[:owner_id], entry[:owner_display_name])
            new(S3, entry[:name], entry[:creation_date], owner)
          end
        end
        alias_method 'buckets', 'list'

        def create(name, perms=nil, headers={})
          bucket(name, create=true, perms, headers)
        end

        def bucket(name, create=false, perms=nil, headers={})
          name = namespaced(name)
          headers['x-amz-acl'] = perms if perms
          S3.interface.create_bucket(name, headers) if create
          list.each{|bucket| return bucket if bucket.name == name}
          nil
        end

        def for(name, options = {})
          result = S3.interface.list_bucket(name.to_s)
          service = result.service
          owner = Owner.new(service[:owner_id], service[:owner_display_name]) # HACK - will always be nil
          bucket = new(S3, service[:name], service[:creation_date], owner)
          owner, grantees = RightAws::S3::Grantee.owner_and_grantees(bucket)
          bucket.owner = owner
          bucket
        end

        def new(*args, &block)
          if args.size == 4
            return super
          else
            Bucket.for(*args, &block)
          end
        end
      end

    # instance methods
    #
      attr_accessor 'owner'

      def put(key, data=nil, meta_headers={}, perms=nil, headers={})
        key = Key.create(self, key.to_s, data, meta_headers) unless key.is_a?(Key) 
        key.put(data, perms, headers)
        key
      end

      def get(key, headers={})
        key = Key.create(self, key.to_s) unless key.is_a?(Key)
        key.get(headers)
        key
      end

      def s3g
        @s3g ||= S3.s3g.bucket(name)
      end

      def create_link
        s3g.create_link
      end

      def public_link
        s3g.public_link
      end

      def list_keys_link options = {}
        options.to_options!
        expires = options.delete(:expires) || 1.hour
        headers = options.delete(:headers) || {}
        s3g.keys(options, expires, headers)
      end

      def root(*args, &block)
        namespace('', *args, &block)
      end

      def namespace(name, *args, &block)
        namespace = Namespace.new(self, name, *args, &block)
=begin
        parts = name.to_s.gsub(%r/(^\/+|\/+$)/,'').gsub(%r/\/+/,'/').split(%r/\//)
        part, *parts = parts
        namespace = Namespace.new(self, part, *args, &block)
        parts.each do |part|
          namespace = Namespace.new(namespace, part, *args, &block)
        end
        namespace
=end
      end
      alias_method 'namespaced', 'namespace'
      alias_method '/', 'namespace'



      class Namespace
        module KeyMethods
        end

        attr :bucket
        attr :name

        def initialize bucket, name, options = {}
          @bucket = bucket
          @name = name.to_s
          @name.sub! %r|^/+|, ''
          @name.sub! %r|/+$|, ''
          @name.sub! %r|/+|, '/'
        end

        alias_method 'prefix', 'name'

        def namespace(name, *args, &block)
          bucket.namespace(File.join(self.name, name.to_s), *args, &block)
        end
        alias_method 'namespaced', 'namespace'
        alias_method '/', 'namespace'

        def keys options = {}
          options.to_options!
          options[:prefix] ||= prefix unless prefix.blank?
          headers = options.delete(:headers)
          bucket.keys(options, headers)
        end

        def put(data, *args, &block)
          options = args.extract_options!.to_options!

          meta = options.delete(:meta) || {}
          perms = options.delete(:perms)
          headers = options.delete(:headers) || {}

          io_for(data) do |io|
            key = key_for(args.shift || io)
            bucket.put(key, io, meta, perms, headers)
          end
        end

        def get(key, *args, &block)
          options = args.extract_options!.to_options!
          headers = options.delete(:headers) || {}
          key = key_for(key)
          bucket.get(key, headers)
        end

        def io_for(arg)
          return(arg.respond_to?(:read) ? yield(arg) : open(arg.to_s){|io| yield(io)})
        end

        def key_for(arg, options = {})
          path = nil
          %w[ path pathname filename ].each do |msg|
            break(path = arg.send(msg).to_s) if arg.respond_to?(msg)
          end
          path ||= arg.to_s
          path.strip!
          raise Errror, "no path in #{ io.inspect }" if path.blank?
          key = File.join('/', prefix, path).squeeze('/')[1..-1].sub(%r|/+$|, '')
        end

        def list_keys_link options = {}
          options.to_options!
          expires = options.delete(:expires) || 1.hour
          headers = options.delete(:headers) || {}
          options[:prefix] = name
          bucket.s3g.keys(options, expires, headers)
        end

        def ls(options = {})
          options.to_options!
          expires = options.delete(:expires) || 1.hour
          headers = options.delete(:headers) || {}
          keys.map do |key|
            bucket.s3g.key(key).get(expires, headers)
          end
        end
      end

    end
  end
end

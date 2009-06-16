module Helene
  module S3
    class Bucket < RightAws::S3::Bucket
      Owner = RightAws::S3::Owner
      Key = RightAws::S3::Key
      Grantee = RightAws::S3::Grantee
      S3Generator = RightAws::S3Generator

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
        Namespace.new(self, name, *args, &block)
      end
      alias_method 'namespaced', 'namespace'
      alias_method '/', 'namespace'


      class Namespace
        attr :bucket
        attr :name

        def initialize bucket, name, options = {}
          @bucket = bucket
          @name = name.to_s
        end

        alias_method 'prefix', 'name'

        def namespace(name, *args, &block)
          bucket.namespace(File.join(self.name, name.to_s), *args, &block)
        end
        alias_method 'namespaced', 'namespace'
        alias_method '/', 'namespace'

        def list options = {}
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
      end

    end
  end
end

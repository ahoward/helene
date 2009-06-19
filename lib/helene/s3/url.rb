module Helene
  module S3
    class Url
      attr_reader :interface
      
      def initialize(aws_access_key_id, aws_secret_access_key, params={})
        @interface = S3Interface.new(aws_access_key_id, aws_secret_access_key, params)
      end
      
        # Generate link to list all buckets
        #
        #  s3.buckets(1.hour)
        #
      def buckets(expires=nil, headers={})
        @interface.list_all_my_buckets_link(expires, headers)
      end

        # Create new S3LinkBucket instance and generate link to create it at S3.
        #
        #  bucket= s3.bucket('my_owesome_bucket')
        #
      def bucket(name, expires=nil, headers={})
        Bucket.create(self, name.to_s)
      end
    
      class Bucket
        attr_reader :s3, :name
        
        def to_s
          @name
        end
        alias_method :full_name, :to_s
          
          # Return a public link to bucket.
          # 
          #  bucket.public_link #=> 'https://s3.amazonaws.com:443/my_awesome_bucket'
          #
        def public_link
          params = @s3.interface.params
          "#{params[:protocol]}://#{params[:server]}:#{params[:port]}/#{full_name}"
        end
        
          #  Create new S3LinkBucket instance and generate creation link for it. 
        def self.create(s3, name, expires=nil, headers={})
          new(s3, name.to_s)
        end
          
          #  Create new S3LinkBucket instance. 
        def initialize(s3, name)
          @s3, @name = s3, name.to_s
        end
          
          # Return a link to create this bucket. 
          #
        def create_link(expires=nil, headers={})
          @s3.interface.create_bucket_link(@name, expires, headers)
        end

          # Generate link to list keys. 
          #
          #  bucket.keys
          #  bucket.keys('prefix'=>'logs')
          #
        def keys(options=nil, expires=nil, headers={})
          @s3.interface.list_bucket_link(@name, options, expires, headers)
        end

          # Return a S3Generator::Key instance.
          #
          #  bucket.key('my_cool_key').get    #=> https://s3.amazonaws.com:443/my_awesome_bucket/my_cool_key?Signature=B...D&Expires=1180820032&AWSAccessKeyId=1...2
          #  bucket.key('my_cool_key').delete #=> https://s3.amazonaws.com:443/my_awesome_bucket/my_cool_key?Signature=B...D&Expires=1180820098&AWSAccessKeyId=1...2
          #
        def key(name)
          Key.new(self, name)
        end

          # Generates link to PUT key data. 
          #
          #  puts bucket.put('logs/today/1.log', 2.hour)
          #
        def put(key, meta_headers={}, expires=nil, headers={})
          meta = RightAws::S3::Key.add_meta_prefix(meta_headers)
          @s3.interface.put_link(@name, key.to_s, nil, expires, meta.merge(headers))
        end
          
          # Generate link to GET key data. 
          #
          #  bucket.get('logs/today/1.log', 1.hour)
          #
        def get(key, expires=nil, headers={})
          @s3.interface.get_link(@name, key.to_s, expires, headers)
        end
         
          # Generate link to delete bucket. 
          #
          #  bucket.delete(2.hour)
          #
        def delete(expires=nil,  headers={})
          @s3.interface.delete_bucket_link(@name, expires,  headers)
        end
      end


      class Key
        attr_reader :bucket, :name
        
        def to_s
          @name
        end
        
          # Return a full S# name (bucket/key).
          # 
          #  key.full_name #=> 'my_awesome_bucket/cool_key'
          #
        def full_name(separator='/')
          "#{@bucket.to_s}#{separator}#{@name}"
        end
          
          # Return a public link to key.
          # 
          #  key.public_link #=> 'https://s3.amazonaws.com:443/my_awesome_bucket/cool_key'
          #
        def public_link
          params = @bucket.s3.interface.params
          "#{params[:protocol]}://#{params[:server]}:#{params[:port]}/#{full_name('/')}"
        end
        
        def initialize(bucket, name, meta_headers={})
          @bucket       = bucket
          @name         = name.to_s
          @meta_headers = meta_headers
          raise 'Key name can not be empty.' if @name.blank?
        end
        
          # Generate link to PUT key data. 
          #
          #  puts bucket.put('logs/today/1.log', '123', 2.hour) #=> https://s3.amazonaws.com:443/my_awesome_bucket/logs%2Ftoday%2F1.log?Signature=B...D&Expires=1180820032&AWSAccessKeyId=1...2
          #
        def put(expires=nil, headers={})
          @bucket.put(@name.to_s, @meta_headers, expires, headers)
        end
          
          # Generate link to GET key data. 
          #
          #  bucket.get('logs/today/1.log', 1.hour) #=> https://s3.amazonaws.com:443/my_awesome_bucket/logs%2Ftoday%2F1.log?Signature=h...M%3D&Expires=1180820032&AWSAccessKeyId=1...2
          #
        def get(expires=nil, headers={})
          @bucket.s3.interface.get_link(@bucket.to_s, @name, expires, headers)
        end
         
          # Generate link to delete key. 
          #
          #  bucket.delete(2.hour) #=> https://s3.amazonaws.com:443/my_awesome_bucket/logs%2Ftoday%2F1.log?Signature=4...D&Expires=1180820032&AWSAccessKeyId=1...2
          #
        def delete(expires=nil,  headers={})
          @bucket.s3.interface.delete_link(@bucket.to_s, @name, expires,  headers)
        end
        
          # Generate link to head key. 
          #
          #  bucket.head(2.hour) #=> https://s3.amazonaws.com:443/my_awesome_bucket/logs%2Ftoday%2F1.log?Signature=4...D&Expires=1180820032&AWSAccessKeyId=1...2
          #
        def head(expires=nil,  headers={})
          @bucket.s3.interface.head_link(@bucket.to_s, @name, expires,  headers)
        end
      end
    end
  end
end

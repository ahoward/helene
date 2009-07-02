testing Bucket = Helene::S3::Bucket do


  context 'with a bucket created' do
    setup do
      create_bucket
    end

    context 'at the class level' do
      should 'be able to delete a bucket' do
        delete_bucket
      end

      should 'be able to list buckets' do
        list = assert{ Bucket.list }
        assert{ list.is_a?(Array) }
        assert{ list.include?(bucket) }
      end

      should 'be able to instantiate a bucket by name' do
        assert{ Bucket.new bucket.name }
      end

      should 'be able to generate a link to view all buckets' do
        url = assert{ Bucket.url }
        assert{ curl(url) =~ /ListAllMyBucketsResult/ }
      end

      should 'be able to generate a link to create a bucket' do
        create_bucket_by_url
      end

      should 'be able to generate a link to delete a bucket' do
        delete_bucket_by_url
      end
    end

    context 'at the instance level' do
      setup do
        @pathname = File.expand_path(__FILE__)
        @basename = File.basename(@pathname)
        @data = IO.read(@pathname)
      end

      should 'be able to put a pathname' do
        object = assert{ bucket.put(@pathname) }
        assert{ curl(object.url) == @data }
      end

      should "be able to put an io - returning an object that knows it's url" do
        object = assert{ open(@pathname){|io| bucket.put(io)} }
        assert{ curl(object.url) == @data }
      end

      should "be able to put/get a path" do
        object = assert{ bucket.put(@pathname) }
        data = assert{ bucket.get(object.name).data }
        assert{ data == @data }
      end
    
      context "with a prefix set" do
        setup do
          bucket.prefix = @prefix = "test_prefix"
        end
        teardown do
          bucket.prefix = nil
        end
      
        should "put under the prefix" do
          object = assert{ bucket.put(@pathname) }
          assert{ object.url.include?("/#{@prefix}/") }
        end

        should "get under the prefix" do
          # ensure Bucket is empty
          clear_bucket
          
          # should be nothing there
          assert{
            begin
              bucket.get(@pathname).data.nil?
              false
            rescue RightAws::AwsError
              true
            end
          }
          
          # now add the data
          object = assert{ bucket.put(@pathname) }
          
          # 
          # ensure that we can now read the data back
          # (without an explicit prefix)
          # 
          data = assert{ bucket.get(object.name).data }
          assert{ data == @data }
        end

        should "list under the prefix" do
          # ensure Bucket is empty
          clear_bucket

          # add a file *not* under the prifx
          bucket.prefix = nil
          assert{ bucket.put(@pathname) }
          assert{ !bucket.ls.empty? }
          
          # ensure the listing is still empty under the prefix
          bucket.prefix = @prefix
          assert{ bucket.ls.empty? }
          
          # add another under the prefix
          assert{ bucket.put(@pathname) }
          assert{ !bucket.ls.empty? }
        end
      end
    end
  end




  def bucket_name(options = {})
    "helene-s3-bucket-test-#{ Helene.uuid }"
  end

  def create_bucket(options = {})
    @bucket ||= assert{ Bucket.create(bucket_name, options) }
    # at_exit{ @bucket.delete(:force => true) rescue nil if @bucket unless $! }
    at_exit{ Bucket.delete(@bucket, :force => true) rescue nil if @bucket }
  end

  def create_bucket_by_url
    name = bucket_name
    url ||= assert{ Bucket.url(:create, name) }
    assert{ curl(url, :PUT) }
    assert{ @bucket_url = Bucket.new(name) }
  end

  def delete_bucket_by_url
    create_bucket_by_url unless @bucket_url
    name = @bucket_url.name
    url ||= assert{ Bucket.url(:delete, name) }
    assert{ curl(url, :DELETE) }
    assert_raises(subclass_of(Exception)){ Bucket.new(name) }
  end

  def bucket
    @bucket
  end

  def delete_bucket(options = {})
    create_bucket unless @bucket
    assert{ Bucket.delete(@bucket, options) }
    @bucket = nil
  end
  
  def clear_bucket(options = {})
    old_prefix    = bucket.prefix
    bucket.prefix = nil              # remove prefix so we get all files
    assert{ bucket.clear(options) }
    assert{ bucket.ls.empty? }       # ensure it is empty
  ensure
    bucket.prefix = old_prefix       # restore prefix
  end

  def curl(url, options = {})
    options = {:method => options} unless options.is_a?(Hash)
    method = options[:method] || :GET
    `curl --silent --insecure --location --request #{ method.to_s } #{ url.inspect } 2>/dev/null`
  end
end

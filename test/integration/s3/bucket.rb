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
        key = assert{ bucket.put(@pathname) }
        assert{ curl(key.url) == @data }
      end

      should "be able to put an io - returning an object that knows it's url" do
        key = assert{ open(@pathname){|io| bucket.put(io)} }
        assert{ curl(key.url) == @data }
      end

      should "be able to put/get a path" do
        key = assert{ bucket.put(@pathname) }
        data = assert{ bucket.get(key.name) }
        assert{ data == @data }
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

  def curl(url, options = {})
    options = {:method => options} unless options.is_a?(Hash)
    method = options[:method] || :GET
    `curl --silent --insecure --location --request #{ method.to_s } #{ url.inspect } 2>/dev/null`
  end
end

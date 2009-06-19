module Helene
  module S3
    class << S3
      def thread
        Thread.current
      end

      def establish_connection(aws_access_key_id=Helene.aws_access_key_id, aws_secret_access_key=Helene.aws_secret_access_key, options={})
        options.to_options!
        thread[:helene_s3_interface] = RightAws::S3Interface.new(aws_access_key_id, aws_secret_access_key, options)
        raise Error, 'Connection to S3 is not established' unless thread[:helene_s3_interface]

        thread[:helene_s3_generator] = RightAws::S3Generator.new(aws_access_key_id, aws_secret_access_key)
        raise Error, 'Connection to S3 is not established' unless thread[:helene_s3_generator]
      end

      def interface
        establish_connection unless thread[:helene_s3_interface]
        thread[:helene_s3_interface]
      end
      alias_method 'connection', 'interface'

      def s3g
        establish_connection unless thread[:helene_s3_generator]
        thread[:helene_s3_generator]
      end

      load 'helene/s3/bucket.rb'
      load 'helene/s3/key.rb'
      load 'helene/s3/owner.rb'
      load 'helene/s3/grantee.rb'
      load 'helene/s3/url.rb'
    end
  end
end

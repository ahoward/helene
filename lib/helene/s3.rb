module Helene
  module S3
    load 'helene/s3/bucket.rb'
    load 'helene/s3/key.rb'
    load 'helene/s3/object.rb'
    load 'helene/s3/owner.rb'
    load 'helene/s3/grantee.rb'
    
    extend Connectable
  end
end

## helene.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "helene"
  spec.version = "0.0.1"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "helene"

  spec.files = ["helene.gemspec", "lib", "lib/helene", "lib/helene/attempt.rb", "lib/helene/aws.rb", "lib/helene/config.rb", "lib/helene/content_type.rb", "lib/helene/content_type.yml", "lib/helene/error.rb", "lib/helene/logging.rb", "lib/helene/objectpool.rb", "lib/helene/rails.rb", "lib/helene/rightscale", "lib/helene/rightscale/acf", "lib/helene/rightscale/acf/right_acf_interface.rb", "lib/helene/rightscale/awsbase", "lib/helene/rightscale/awsbase/benchmark_fix.rb", "lib/helene/rightscale/awsbase/right_awsbase.rb", "lib/helene/rightscale/awsbase/support.rb", "lib/helene/rightscale/ec2", "lib/helene/rightscale/ec2/right_ec2.rb", "lib/helene/rightscale/net_fix.rb", "lib/helene/rightscale/right_aws.rb", "lib/helene/rightscale/right_http_connection.rb", "lib/helene/rightscale/s3", "lib/helene/rightscale/s3/right_s3.rb", "lib/helene/rightscale/s3/right_s3_interface.rb", "lib/helene/rightscale/sdb", "lib/helene/rightscale/sdb/active_sdb.rb", "lib/helene/rightscale/sdb/right_sdb_interface.rb", "lib/helene/rightscale/sqs", "lib/helene/rightscale/sqs/right_sqs.rb", "lib/helene/rightscale/sqs/right_sqs_gen2.rb", "lib/helene/rightscale/sqs/right_sqs_gen2_interface.rb", "lib/helene/rightscale/sqs/right_sqs_interface.rb", "lib/helene/s3", "lib/helene/s3/bucket.rb", "lib/helene/s3/grantee.rb", "lib/helene/s3/key.rb", "lib/helene/s3/owner.rb", "lib/helene/s3.rb", "lib/helene/sdb", "lib/helene/sdb/base", "lib/helene/sdb/base/associations.rb", "lib/helene/sdb/base/attributes.rb", "lib/helene/sdb/base/connection.rb", "lib/helene/sdb/base/error.rb", "lib/helene/sdb/base/hooks.rb", "lib/helene/sdb/base/literal.rb", "lib/helene/sdb/base/logging.rb", "lib/helene/sdb/base/transactions.rb", "lib/helene/sdb/base/type.rb", "lib/helene/sdb/base/types.rb", "lib/helene/sdb/base/validations.rb", "lib/helene/sdb/base.rb", "lib/helene/sdb/cast.rb", "lib/helene/sdb/connection.rb", "lib/helene/sdb/error.rb", "lib/helene/sdb/interface.rb", "lib/helene/sdb/sentinel.rb", "lib/helene/sdb.rb", "lib/helene/sleepcycle.rb", "lib/helene/superhash.rb", "lib/helene/util.rb", "lib/helene.rb", "Rakefile", "test", "test/auth.rb", "test/helper.rb", "test/integration", "test/integration/begin.rb", "test/integration/ensure.rb", "test/integration/s3", "test/integration/s3/bucket.rb", "test/integration/sdb", "test/integration/sdb/associations.rb", "test/integration/sdb/creating.rb", "test/integration/sdb/emptiness.rb", "test/integration/sdb/hooks.rb", "test/integration/sdb/limits.rb", "test/integration/sdb/saving.rb", "test/integration/sdb/selecting.rb", "test/integration/sdb/types.rb", "test/integration/sdb/validations.rb", "test/integration/setup.rb", "test/integration/teardown.rb", "test/loader.rb", "test/log"]
  spec.executables = []
  
  spec.require_path = "lib"

  spec.has_rdoc = true
  spec.test_files = nil
  #spec.add_dependency 'lib', '>= version'
  #spec.add_dependency 'fattr'

  spec.extensions.push(*[])

  spec.rubyforge_project = "codeforpeople"
  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "http://github.com/ahoward/helene/tree/master"
end

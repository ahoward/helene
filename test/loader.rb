# sets up the required environment for running tests
#
  $src_dir = File.expand_path(File.dirname(File.dirname(__FILE__)))
  $lib_dir = File.join($src_dir, 'lib')
  $test_dir = File.join($src_dir, 'test')
  $test_lib_dir = File.join($src_dir, 'test', 'lib')
  $test_data_dir = File.join($src_dir, 'test', 'data')
  $test_unit_dir = File.join($test_dir, 'unit')
  $test_unit_lib_dir = File.join($test_unit_dir, 'lib')
  $test_integration_dir = File.join($test_dir, 'integration')
  $test_integration_lib_dir = File.join($test_integration_dir, 'lib')
  $test_config_file = File.join($test_dir, 'config.yml')

  $test_integration_setup_guard = File.join($test_integration_dir, '.guard')
  $test_log = File.join($test_dir, 'log')

  $load_path = [$lib_dir, $test_dir, $test_lib_dir]
  $load_path.each{|load_path| $LOAD_PATH.unshift(load_path)}
  ENV['RUBYLIB'] = $LOAD_PATH.join(File::PATH_SEPARATOR)

  Dir.chdir($src_dir)

  require 'test/unit'

  begin
    require 'rubygems'
  rescue LoadError
    nil
  end

  require 'shoulda'

  require File.join($lib_dir, 'helene')
  require File.join($test_dir, 'helper')

  Helene.logger = $test_log

  STDOUT.sync = true
  STDERR.sync = true

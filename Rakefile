task :default do
  puts(Rake::Task.tasks.map{|task| task.name} - ['default'])
end

namespace 'test' do
  def test_files(prefix=nil, &block)
    files = [ENV['FILES'], ENV['FILE']].flatten.compact
    if files.empty?
      files = Dir.glob("#{ prefix }/**/*.rb")
    else
      files.map!{|file| Dir.glob(file)}.flatten.compact
    end
    files = files.join(' ').strip.split(%r/\s+/)
    files.delete_if{|file| file =~ /(begin|ensure|setup|teardown).rb$/}
    files.delete_if{|file| !test(?s, file) or !test(?f, file)}
    files.delete_if{|file| !file[%r/#{ prefix }/]}
    block ? files.each{|file| block.call(file)} : files
  end

  desc 'run all tests'
  task 'all' => %w[ unit integration ] do
  end

  desc 'run unit tests'
  task 'unit' do
    test_files('test/unit/') do |file|
      test_loader file
    end
  end

  desc 'run integration tests'
  task 'integration' do
    test_files('test/integration/') do |file|
      test_loader file, :require_auth => true
    end
  end

  namespace 'integration' do
    task 'setup' do
      test_loader 'test/integration/setup.rb', :require_auth => true
    end
    task 'teardown' do
      test_loader 'test/integration/teardown.rb', :require_auth => true
    end
  end
end

task('test' => 'test:all'){}



BEGIN {
  ENV['PATH'] = [ '.', './bin/', ENV['PATH'] ].join(File::PATH_SEPARATOR)

  $VERBOSE = nil

  require 'time'
  require 'ostruct'
  require 'erb'
  require 'fileutils'

  Fu = FileUtils

  This = OpenStruct.new

  This.file = File.expand_path(__FILE__)
  This.dir = File.dirname(This.file)
  This.pkgdir = File.join(This.dir, 'pkg')

  lib = ENV['LIB']
  unless lib
    lib = File.basename(Dir.pwd)
  end
  This.lib = lib

  version = ENV['VERSION']
  unless version
    name = lib.capitalize
    require "./lib/#{ lib }"
    version = eval(name).send(:version)
  end
  This.version = version

  abort('no lib') unless This.lib
  abort('no version') unless This.version

  module Util
    def indent(s, n = 2)
      s = unindent(s)
      ws = ' ' * n
      s.gsub(%r/^/, ws)
    end

    def unindent(s)
      indent = nil
      s.each do |line|
      next if line =~ %r/^\s*$/
      indent = line[%r/^\s*/] and break
    end
    indent ? s.gsub(%r/^#{ indent }/, "") : s
  end
    extend self
  end

  class Template
    def initialize(&block)
      @block = block
      @template = block.call.to_s
    end
    def expand(b=nil)
      ERB.new(Util.unindent(@template)).result(b||@block)
    end
    alias_method 'to_s', 'expand'
  end
  def Template(*args, &block) Template.new(*args, &block) end

  def test_loader basename, options = {}
    tests = ENV['TESTS']||ENV['TEST']
    tests = " -- -n #{ tests.inspect }" if tests
    auth = '-r test/auth.rb ' if options[:require_auth]
    command = "ruby -r test/loader.rb #{ auth }#{ basename }#{ tests }"
    STDERR.print "\n==== TEST ====\n  #{ command }\n\n==============\n"
    system command or abort("#{ command } # FAILED WITH #{ $?.inspect }")
  end

  Dir.chdir(This.dir)
}

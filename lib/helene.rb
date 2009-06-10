module Helene
# version
#
  Helene::VERSION = '0.0.0'
  def Helene.version() Helene::VERSION end

# ruby built-ins
#
  require 'ostruct'
  require 'logger'
  require 'pathname'

# rubygems
#
  begin
    require 'rubygems'
  rescue LoadError
    nil
  end

# gems
#
  require 'active_support' unless defined?(ActiveSupport)
  require 'right_aws'
  require 'uuidtools'
  gem 'arrayfields', '>= 4.7.4'
  require 'arrayfields'
  gem 'threadify', '>= 1.1.0'
  require 'threadify'

# helene load support
#
  def Helene.libdir(*args)
    @libdir ||= Pathname.new(__FILE__).realpath.dirname
    if args.empty?
      @libdir
    else
      File.join(@libdir, *args.flatten.compact.map{|arg| arg.to_s})
    end
  end

  def Helene.load(lib)
    Kernel.load Helene.libdir(lib)
  end

  def Helene.load_path(&block)
    $LOAD_PATH.unshift(Helene.libdir)
    begin
      block.call
    ensure
      $LOAD_PATH.shift
    end
  end

# helene
#
  Helene.load_path do
    load 'helene/error.rb'
    load 'helene/util.rb'
    load 'helene/logging.rb'
    load 'helene/config.rb'
    load 'helene/aws.rb'
    load 'helene/sdb.rb'
    load 'helene/s3.rb'
  end

# mega-hacks
#
  ca_file =
    ENV['CA_FILE'] ||
    ENV['AMAZON_CA_FILE'] ||
    (defined?(AMAZON_CA_FILE) and AMAZON_CA_FILE) ||
    (defined?(CA_FILE) and CA_FILE)
  Rightscale::HttpConnection.params[:ca_file] = ca_file if ca_file
end

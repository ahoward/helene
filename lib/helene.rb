module Helene
# version
#
  Helene::VERSION = '0.0.0'
  def Helene.version() Helene::VERSION end

# ruby built-ins
#
  require 'ostruct'
  require 'logger'

# rubygems
#
  begin
    require 'rubygems'
  rescue LoadError
    nil
  end

# gems
#
  require 'active_support' unless defined?(Rails)
  require 'right_aws'
  require 'uuidtools'
  require 'arrayfields'

# load support
#
  def Helene.libdir(*args)
    @libdir ||= File.expand_path(File.dirname(__FILE__))
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

# boot helene
#
  Helene.load_path do
    load 'helene/error.rb'
    load 'helene/util.rb'
    load 'helene/logger.rb'
    load 'helene/config.rb'
    load 'helene/aws.rb'
    load 'helene/sdb.rb'
    load 'helene/s3.rb'
  end
end

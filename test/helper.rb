module Helene
  module Test
    module Helper
    end
  end
end

module Kernel
private
  def Testing(*args, &block)
    Class.new(::Test::Unit::TestCase) do
      include Helene::Test::Helper
      args.push 'default' if args.empty?
      context(*args, &block)
    end
  end
end


module Helene
  module Test
    module Helper
      def eventually_assert(label = nil, &block)
        42.times do
          bool = block.call

          if bool
            args = [bool, label]
            assert(*args)
            return true
          end

          STDERR.warn "#{ label.to_s.inspect } not true yet..."

          sleep(rand)
        end
        false
      end
    end
  end
end

module Kernel
private
  def testing(*args, &block)
    Class.new(::Test::Unit::TestCase) do
      include Helene::Test::Helper

      alias_method '__assert__', 'assert'

      def assert(*args, &block)
        if block
          label = 'assertion: ' + args.join(' ')
          result = nil
          assert_nothing_raised{ result = block.call }
          __assert__(result, label)
          result
        else
          __assert__(*args)
          args.first
        end
      end

      args.push 'default' if args.empty?
      context(*args, &block)
    end
  end
end


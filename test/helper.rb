module Helene
  module Test
    Helper = lambda do
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

      def eventually_assert(label = nil, &block)
        min = 0.01
        max = 1.28
        sleeps = []
        m = min
        while m < max; sleeps << m and m *= 2; end
        
        42.times do |i|
          bool = block.call
          if bool
            args = [bool, label]
            assert(*args)
            return true
          end
          STDERR.puts "\n#{ label.to_s.inspect } not true yet..."
          sleep(sleeps[ i % sleeps.size ])
        end
        STDERR.puts "\n#{ label.to_s.inspect } *never* became true!"
        false
      end


      def model(name, &block)
        name = name.to_s
        @models ||= {}
        @models[name] ||= Class.new(Helene::Sdb::Base){ domain "helene-test-model-#{ name }" }
        @models[name].module_eval(&block) if block
        @models[name]
      end

      def models
        ('a' .. 'e').map{|name| model(name)}
      end
    end
  end
end

module Kernel
private
  def testing(*args, &block)
    Class.new(::Test::Unit::TestCase) do
      module_eval &Helene::Test::Helper
      args.push 'default' if args.empty?
      context(*args, &block)
    end
  end
end


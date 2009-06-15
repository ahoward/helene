module Helene
  module Test
    module Models
      def model(name, &block)
        name = name.to_s
        @models ||= {}
        @models[name] ||= Class.new(Helene::Sdb::Base){ domain "helene-test-model-#{ name }" }
        class_name = name.classify
        ::Object.send(:remove_const, class_name) if ::Object.const_defined?(class_name)
        ::Object.const_set(class_name, @models[name])
        @models[name].module_eval(&block) if block
        @models[name]
      end

      def models
        ('a' .. 'e').map{|name| model(name)}
      end

      extend self
    end

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

      def eventually_assert(*args, &block)
        options = args.extract_options!.to_options!
        first = args.shift || caller.first(1)
        label = "eventually_assert(#{ first.to_s.inspect })"

        min = 0.01
        max = 1.28
        sleeps = []
        m = min
        while m < max; sleeps << m and m *= 2; end
        
        a = Time.now.to_f
        42.times do |i|
          bool =
            begin
              block.call
            rescue => e
              m, c, b = e.message, e.class, (e.backtrace||{}).join("\n")
              STDERR.puts "\n#{ m }(#{ c })\n#{ b }"
              false
            end
          if bool
            args = [bool, label]
            assert(*args)
            return true
          end
          STDERR.puts "\n#{ label.to_s } (not true yet...)"
          sleep(sleeps[ i % sleeps.size ])
        end
        b = Time.now.to_f
        elapsed = b - a
        STDERR.puts "\n#{ label.to_s } (never became true in #{ elapsed } seconds!)"
        assert(false, label)
      end

      include Models
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


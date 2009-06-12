module Helene
  class SleepCycle < ::Array
    Min = 0.01
    Max = 1.28

    attr_accessor :min
    attr_accessor :max
    attr_accessor :pos

    def initialize(*args)
      options = args.extract_options!.to_options!
      @min = options[:min] || Min
      @max = options[:max] || Max
      m = @min
      while m < @max; push(m) and m *= 2; end
      @pos = 0
    end

    def next
      self[@pos]
    ensure
      @pos = ((@pos + 1) % size)
    end

    def reset
      @pos = 0
    end
  end
end

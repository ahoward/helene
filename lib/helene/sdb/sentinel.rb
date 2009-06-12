module Helene
  module Sdb
    module Sentinel
      Nil = 'nil' unless defined?(Sentinel::Nil)
      Set = '[]' unless defined?(Sentinel::Set)

      class << Sentinel
        def Nil() Nil end
        def nil() Nil end
        def Set() Set end
        def set() Set end
      end
    end
  end
end

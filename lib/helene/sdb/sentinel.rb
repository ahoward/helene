module Helene
  module Sdb
    module Sentinel
      Nil = 'nil'
      Array = '[]'

      class << Sentinel
        def Nil() Nil end
        def nil() Nil end
        def Array() Array end
        def array() Array end
      end
    end
  end
end

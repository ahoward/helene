module Helene
  module Sdb
    class Base
      class Literal < ::String
        def Literal.for(*args)
          new(args.join)
        end
        def literal?
          true
        end
        def literal
          self
        end
      end

      class << Base
        def literal(*args)
          Literal.for(*args)
        end
        def Literal(*args)
          Literal.for(*args)
        end
        def literal?(*args)
          args.all?{|arg| Literal === arg}
        end
        def Literal?(*args)
          args.all?{|arg| Literal === arg}
        end
      end

      def literal(*args)
        Literal.for(*args)
      end
      def Literal(*args)
        Literal.for(*args)
      end
      def literal?(*args)
        args.all?{|arg| Literal === arg}
      end
      def Literal?(*args)
        args.all?{|arg| Literal === arg}
      end
    end
  end
end

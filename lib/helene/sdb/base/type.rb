module Helene
  module Sdb
    class Base
      class Type
        unless defined?(INT_FMT)
          INT_N_BYTES  = [42].pack('i').size
          INT_N_BITS   = INT_N_BYTES * 8
          INT_MAX      = 2 ** (INT_N_BITS - 2) - 1
          INT_MIN      = -INT_MAX - 1
          INT_OFF      = INT_MAX / 2
          INT_MAX_SIZE = INT_MAX.to_s.size
          INT_MIN_SIZE = INT_MAX.to_s.size
          INT_SIZE     = [INT_MAX_SIZE, INT_MIN_SIZE].max
          INT_FMT      = "%0#{ INT_SIZE }d"
        end

        class << Type
          def ruby_to_sdb(value=nil, &block)
            if block
              define_method(:ruby_to_sdb, &block)
            else
              value
            end
          end

          def sdb_to_ruby(value=nil, &block)
            if block
              define_method(:sdb_to_ruby, &block)
            else
              value
            end
          end

          def array_of_string value
            [value].flatten.map{|val| val.to_s}
          end

          def format(&block)
            define_method(:format, &block)
          end

          def list
            @list ||= Array.fields
          end
          
          def for name
            list[name.to_s.underscore]
          end

          def listify(*list)
            [list].join(',').strip.split(%r/\s*,\s*/)
          end

          def type(name, *args, &block)
            name = name.to_s.underscore
            type_instance = args.first
            unless type_instance
              const = name.camelize
              if Type.const_defined?(const)
                type_class = Type.const_get(const)
              else
                type_class = Class.new(Type)
                Type.const_set(const, type_class)
              end
              type_class.module_eval(&block)
              type_instance = type_class.new()
            end
            list[name] = type_instance
          end
          alias_method 'register_type', 'type'
        end

        def ruby_to_sdb(value)
          value
        end

        def sdb_to_ruby(value)
          value
        end

        def name
          self.class.name.split(%r/::/).last.underscore
        end

        def sti?
          name == 'sti'
        end
      end
    end
  end
end

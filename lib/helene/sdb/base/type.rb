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
          def ruby_to_sdb(value)
            value==nil ? Sentinel.Nil : value
          end

          def sdb_to_ruby(value)
            value==Sentinel.Nil ? nil : value
          end

          def ruby_to_sdb_for(&block)
            block ||= lambda{|value| value}
            lambda{|value| value==nil ? Sentinel.Nil : block.call(value)}
          end

          def sdb_to_ruby_for(&block)
            block ||= lambda{|value| value}
            lambda{|value| value==Sentinel.Nil ? nil : block.call(value)}
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

          def name
            @name ||= super
          end
          attr_writer :name

          def type(name, *args, &block)
            name = name.to_s.underscore
            type = new(name, &block)
            list[type.name] = type

            ["set_of_#{ name.singularize }", "set_of_#{ name.pluralize }"].uniq.each do |set_of_name|
              set_of_type =
                new(set_of_name) do
                  ruby_to_sdb do |values|
                    values = Array(values).flatten
                    values.each{|value| type.ruby_to_sdb(value)}
                  end
                  sdb_to_ruby do |values|
                    values = Array(values).flatten
                    values.each{|value| type.sdb_to_ruby(value)}
                  end
                end
              list[set_of_type.name] = set_of_type
            end

            type
          end
          alias_method 'register_type', 'type'
        end

      # instance methods
      #
        attr_accessor :name

        def initialize name, &block
          @name = name
          @ruby_to_sdb = Type.method(:ruby_to_sdb).to_proc
          @sdb_to_ruby = Type.method(:sdb_to_ruby).to_proc
          instance_eval(&block)
        end

        def ruby_to_sdb(value=nil, &block)
          if block
            @ruby_to_sdb = Type.ruby_to_sdb_for(&block)
          else
            @ruby_to_sdb.call(value)
          end
        end

        def sdb_to_ruby(value=nil, &block)
          if block
            @sdb_to_ruby = Type.sdb_to_ruby_for(&block)
          else
            @sdb_to_ruby.call(value)
          end
        end

        def sti?
          name == 'sti'
        end
      end
    end
  end
end

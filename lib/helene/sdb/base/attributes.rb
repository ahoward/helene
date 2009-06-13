module Helene
  module Sdb
    class Base
      class Attribute
        attr_accessor 'base'
        attr_accessor 'name'
        attr_accessor 'type'
        attr_accessor 'nilable'
        attr_accessor 'default'
        attr_accessor 'has_default'
        alias_method 'has_default?', 'has_default'

        def initialize(*args, &block)
          options = args.extract_options!.to_options!

          @base = args.shift || raise(ArgumentError, 'no base')

          @name = args.shift || raise(ArgumentError, 'no name')
          @name = @name.to_s

          type = args.empty? ? (options[:type]||:string) : args.shift.to_s.to_sym

          @type = Type.for(type) || raise(ArgumentError, {:type => type}.inspect)

          not_nilable = [:nil, :null, :nilable, :nullable].any?{|k| options[k]==false} 
          @nilable = !not_nilable

          @default = options[:default]
          @has_default = options.has_key?(:default)

          code = <<-__
            def #{ name }()
              attributes[#{ name.inspect }]
            end
            alias_method #{ name.inspect }+'?', #{ name.inspect }
            def #{ name }=(value)
              attributes[#{ name.inspect }]=value
            end
            if not #{ @nilable }
              validates_presence_of #{ name.inspect }
            end
          __

          @base.module_eval(code, __FILE__, __LINE__)
        end

        def initialize_record(record)
          unless record.attributes.has_key?(name)
            if has_default?
              value =
                if default.respond_to?(:call)
                  record.instance_eval(&default)
                else
                  default
                end
              record.send("#{ name }=", value)
            else
              record.send("#{ name }=", nil)
            end
          end

          if type.sti?
            record.attributes[name] ||= record.class.name
          end
        end
      end

      class << Base
        def attribute(*args, &block)
          attribute = Attribute.new(self, *args, &block)
          attributes[attribute.name] = attribute
        end

        def attributes
          unless defined?(@attributes)
            if self == Base
              @attributes ||= Array.fields
            else
              parent = ancestors[1]
              @attributes = parent.attributes.clone # inherit attributes - recurses up
            end
          end
          @attributes
        end

=begin
 ## dynamically inherit

        def attributes
          @attributes ||= Array.fields
          attributes = @attributes.clone
          superclasses.reverse.each do |superclass|
            superclass.attributes.each do |name, attribute|
              attributes[name] ||= attribute
            end
          end
          attributes
        end
=end

        def attribute_for(name)
          attributes[name.to_s]
        end

        def type_for(name)
          name = name.to_s
          attributes[name].type if attributes.has_key?(name)
        end
      end

      @@attributes = Hash.new
    end
  end
end

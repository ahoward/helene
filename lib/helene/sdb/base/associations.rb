module Helene
  module Sdb
    class Base
      class Association
        def Association.attr(name)
          module_eval <<-__
            def #{ name }(*value) (value.empty? ? (@#{ name }||=nil) : (self.#{ name }=value.first)) end
            def #{ name }=(value) @#{ name } = value end
            def #{ name }?() !!self.#{ name } end
          __
        end


        attr :base
        attr :name
        attr :options
        attr :class_name
        attr :foreign_key

        def initialize(base, name, options = {}, &block)
          @base = base
          @name = name.to_s
          @options = options.to_options!

          instance_eval(&block) if block
          @class_name ||= options[:class_name] || @name.camelize.singularize

          association = self
          @base.module_eval do
            define_method("#{ name }_association"){ association }
          end
        end

        def associated_class
          @associated_class ||= class_name.constantize
        end


        class OneToMany < Association
          attr :list
          attr :polymorphic
          attr :foreign_type
          attr :foreign_key

          def initialize(base, name, options = {}, &block)
            super

            @polymorphic ||= options[:polymorphic]

            if @polymorphic
              @foreign_type ||= "#{ @polymorphic }_type"
              @foreign_key ||= "#{ @polymorphic }_id"
            end

            @foreign_key ||= options[:foreign_key] ||
                             "#{ @base.name.downcase }_id"

            @base.module_eval <<-__
              def #{ name }(*args, &block)
                #{ name }_association.list(self, *args, &block)
              end

              def #{ name }=(*args, &block)
                raise NotImplementedError
              end
            __
            
            @lists = Hash.new
          end

          def list(record, *args, &block)
            return List.new(record, self, *args, &block) if record.new_record?
            forcing           =   args.options.delopt(:force)
            @lists[record.id] =   nil if forcing
            @lists[record.id] ||= List.new(record, self, *args, &block)
          end

          class List < ::Array
            attr :parent
            attr :association

            def initialize(parent, association, *args, &block)
              @parent = parent
              @association = association
              reload
            end

            def parent_class
              associated_class
            end

            def parent_type
              parent_class.name
            end

            def parent_id
              parent.id
            end

            %w[ foreign_type foreign_key associated_class ].each do |attr|
              module_eval <<-__
                def #{ attr }(*a, &b) association.send('#{ attr }', *a, &b) end
                def #{ attr }=(*a, &b) association.send('#{ attr }=', *a, &b) end
              __
            end

            def reload
              conditions = {}

              foreign_type = association.foreign_type
              foreign_key = association.foreign_key

              if foreign_type
                conditions[foreign_type] = parent_type
              end

              conditions[foreign_key] = parent_id

              records = associated_class.select(:all, :conditions => conditions)
              replace records
              self
            end

            def build(attributes = {})
              record = parent_class.new(attributes)
              record.send("#{ foreign_type }=", parent_type) if foreign_type
              record.send("#{ foreign_key }=", parent_id)
              self << record
              record
            end

            def create(attributes = {})
              build(attributes).save
            end

            def create!(attributes = {})
              build(attributes).save!
            end

            def save
              each.map{|record| record.save}
            end

            def save!
              each.map{|record| record.save!}
            end

            def valid?
              each.map{|record| record.valid?}.all?
            end

            def validate!
              each.map{|record| record.validate!}
            end
          end
        end

        class ManyToOne < Association
        end

        class ManyToMany < Association
        end
      end


      class << Base
        def associations()
          @associations ||= Array.fields
        end

        def association(type, *args, &block)
          association =
            case type.to_s.to_sym
              when :one_to_many
                Association::OneToMany.new(self, *args, &block)
              when :many_to_one
                Association::ManyToOne.new(self, *args, &block)
              when :many_to_many
                Association::ManyToMany.new(self, *args, &block)
            end
          associations[association.name] = association
        end
        alias_method 'associate', 'association'
        alias_method 'associates', 'association'

        def has_many(*args, &block)
          associates(:one_to_many, *args, &block)
        end
        def one_to_many(*args, &block)
          associates(:one_to_many, *args, &block)
        end
      end
    end
  end


end


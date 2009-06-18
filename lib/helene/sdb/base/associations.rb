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
        attr :dependent

        def initialize(base, name, options = {}, &block)
          @base = base
          @name = name.to_s
          @options = options.to_options!

          instance_eval(&block) if block
          @class_name ||= (options[:class_name] || @name.camelize.singularize).to_s
          @dependent ||= (options[:dependent] || :nullify).to_s.to_sym

          association = self
          @base.module_eval do
            define_method("#{ name }_association"){ association }
          end
        end

        def associated_class
          @associated_class ||= class_name.constantize
        end

        def initialize_record(record)
          :abstract
        end

        class HasMany < Association
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

            @foreign_key ||= (options[:foreign_key] || @base.name.foreign_key).to_s

            lineno, code = __LINE__ + 1, <<-__
              def #{ name }(*args, &block)
                association = #{ name }_association()
                @#{ name } ||= nil
                options = args.extract_options!.to_options!
                forcing = options.delete(:force)
                @#{ name } =  nil if forcing
                @#{ name } ||= association.list_for(self, *args, &block)
              end

              def #{ name }=(*values)
                value = values.first

                list = #{ name }()
                list.clear!

                case value
                  when Hash
                    list.build(value)
                  when Array
                    list.associate(*value)
                  when Base
                    list.associate(value)
                  else
                    list.associate(*values.flatten)
                end
              end
            __
            filename = __FILE__
            eval code, @base.module_eval('binding'), filename, lineno
          end

          def list_for(record, *args, &block)
            List.new(record, self, *args, &block)
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

            %w[ foreign_type foreign_key associated_class dependent ].each do |attr|
              module_eval <<-__
                def #{ attr }(*a, &b) association.send('#{ attr }', *a, &b) end
                def #{ attr }=(*a, &b) association.send('#{ attr }=', *a, &b) end
              __
            end

            def destroy_all
              each{|record| record.destroy}
            end

            def delete_all
              each{|record| record.delete}
            end

            def nullify_all
              each do |record|
                record.send("#{ foreign_key }=", nil)
                record.send("#{ foreign_type }=", nil) if foreign_type
              end
            end

            def clear!
              case dependent
                when :destroy
                  destroy_all
                when :delete
                  delete_all
                when :nullify, nil
                  nullify_all
              end
              clear
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
              self.push(record)
              record
            end

            def associate(*records)
              Array(records).flatten.each do |record|
                record.send("#{ foreign_type }=", parent_type) if foreign_type
                record.send("#{ foreign_key }=", parent_id)
                self.push(record)
              end
            end
            
            def <<(record)
              associate(record)
            end

            def create(attributes = {})
              build(attributes).save
            end

            def create!(attributes = {})
              build(attributes).save!
            end

            def save
              map!{|record| record.save}
              self
            end

            def save!
              map!{|record| record.save!}
              self
            end

            def valid?
              map{|record| record.valid?}.all?
            end

            def validate!
              map{|record| record.validate!}
            end
          end
        end

        class BelongsTo < Association
          attr :polymorphic
          attr :foreign_type

          def initialize(base, name, options = {}, &block)
            super

            @polymorphic ||= options[:polymorphic]

            if @polymorphic
              @foreign_type ||= "#{ @polymorphic }_type"
              @foreign_key ||= "#{ @polymorphic }_id"
            end

            @foreign_key ||= options[:foreign_key] || class_name.foreign_key

            lineno, code = __LINE__ + 1, <<-__
              def #{ name }(*args, &block)
                @#{ name }_record ||= nil
                options = args.extract_options!.to_options!
                forcing = options.delete(:force)
                @#{ name }_record =   nil if forcing
                @#{ name }_record ||= #{ name }_association.get(self, *args, &block)
              end

              def #{ name }=(value)
                #{ name }_association.set(self, value)
              end

              def build_#{ name }(attributes = {})
                record         = #{ class_name }.new(attributes)
                self.#{ name } = record
                record
              end

              def create_#{ name }(attributes = {})
                record = build_#{ name }(attributes)
                record.save
                record
              end
              # attribute #{ foreign_key.inspect }, :string, :null => #{ !!options[:null] }
            __
            filename = __FILE__
            eval code, @base.module_eval('binding'), filename, lineno
          end

          def get(record, *args, &block)
            find_associated_object_for(record)
          end

          def find_associated_object_for(record)
            return nil unless record[foreign_key]
            conditions = {}
            if foreign_type
              conditions[foreign_type] = class_name
            end
            conditions[:id] = record[foreign_key]
            associated = associated_class.find(:first, :conditions => conditions)
          end

          def set(record, value)
            record[foreign_key] = value.is_a?(Base) ? value.id : value
            value
          end
        end

        class HasOne < Association
          attr :polymorphic
          attr :foreign_type
          attr :pluralized

          def initialize(base, name, options = {}, &block)
            super

            @polymorphic ||= options[:polymorphic]

            if @polymorphic
              @foreign_type ||= "#{ @polymorphic }_type"
              @foreign_key ||= "#{ @polymorphic }_id"
            end

            @foreign_key ||= (options[:foreign_key] || @base.name.foreign_key).to_s

            @pluralized = pluralized = name.to_s.pluralize

            @base.module_eval {
              unless instance_methods.include?(pluralized)
                has_many(pluralized, options, &block)
              end
            }

            lineno, code = __LINE__ + 1, <<-__
              def #{ name }(*args, &block)
                @#{ name } ||= nil
                options = args.extract_options!.to_options!
                forcing = options.delete(:force)
                @#{ name } =  nil if forcing
                @#{ name } ||= #{ pluralized }().first
              end

              def #{ name }=(value)
                if old = #{ name }()
                  case #{ dependent.inspect }
                  when :destroy
                    old.destroy
                  when :delete
                    old.delete
                  when :nullify, nil
                    old.send("#{ foreign_key }=",  nil)
                    old.send("#{ foreign_type }=", nil) if #{ !!foreign_type }
                  end
                end
                self.#{ pluralized } = [value]
              end

              def build_#{ name }(attributes = {})
                record         = #{ class_name }.new(attributes)
                self.#{ name } = record
                record
              end

              def create_#{ name }(attributes = {})
                record = build_#{ name }(attributes)
                record.save
                record
              end
            __
            filename = __FILE__
            eval code, @base.module_eval('binding'), filename, lineno
          end
        end


        class << Base
          def associations()
            @associations ||= Array.fields
          end

          def association(type, *args, &block)
            association =
              case type.to_s.to_sym
                when :has_many
                  Association::HasMany.new(self, *args, &block)
                when :belongs_to
                  Association::BelongsTo.new(self, *args, &block)
                when :has_one
                  Association::HasOne.new(self, *args, &block)
              end
            associations[association.name] = association
          end
          alias_method 'associate', 'association'
          alias_method 'associates', 'association'

          def has_many(*args, &block)
            associates(:has_many, *args, &block)
          end
          def belongs_to(*args, &block)
            associates(:belongs_to, *args, &block)
          end
          def has_one(*args, &block)
            associates(:has_one, *args, &block)
          end
        end

      end
    end
  end
end


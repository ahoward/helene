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
        attr :foreign_keys
        attr :dependent
        attr :conditions

        def initialize(base, name, options = {}, &block)
          @base = base
          @name = name.to_s
          @options = options.to_options!

          instance_eval(&block) if block
          @class_name ||= (options[:class_name] || @name.camelize.singularize).to_s
          @dependent ||= (options[:dependent] || :nullify).to_s.to_sym

          @conditions = (options[:conditions] || {}).to_options!
          @foreign_keys = options[:foreign_keys]

          association = self
          @base.module_eval do
            define_method("#{ name }_association"){ association }
          end
        end

        def conditions_for(conditions)
          self.conditions.dup.update(conditions.to_options)
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

            if @foreign_keys
              if @foreign_keys == true
                @foreign_keys = associated_class.name.foreign_key.pluralize.to_sym
              else
                @foreign_keys = @foreign_keys.to_s.to_sym
              end
            else
              @polymorphic ||= options[:polymorphic]

              if @polymorphic
                @foreign_type ||= "#{ @polymorphic }_type"
                @foreign_key ||= "#{ @polymorphic }_id"
              end

              if options.has_key?(:foreign_key)
                @foreign_key = options[:foreign_key]
              else
                @foreign_key ||= @base.name.foreign_key.to_s
              end
            end

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

            def reload
              if foreign_keys
                ids = Array(parent.send(foreign_keys))
                records = ids.empty? ? [] : associated_class.select(ids)
              else
                conditions = {}

                foreign_type = association.foreign_type
                foreign_key = association.foreign_key

                if foreign_type
                  conditions[foreign_type] = parent_type
                end

                conditions[foreign_key] = parent_id

                records = associated_class.select(:all, :conditions => conditions_for(conditions))
              end
              replace records
              self
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

            %w[ foreign_keys foreign_type foreign_key associated_class dependent conditions_for ].each do |attr|
              module_eval <<-__
                def #{ attr }(*a, &b) association.send('#{ attr }', *a, &b) end
                def #{ attr }=(*a, &b) association.send('#{ attr }=', *a, &b) end
              __
            end

            def destroy_all
              parent.transaction do
                each do |record|
                  record.destroy
                  if foreign_keys
                    ids = Array(parent.send(foreign_keys))
                    ids -= Array(record.id)
                    parent.put_attributes(foreign_keys => ids)
                  end
                end
              end
            end

            def delete_all
              parent.transaction do
                each do |record|
                  record.delete
                  if foreign_keys
                    ids = Array(parent.send(foreign_keys))
                    ids -= Array(record.id)
                    parent.put_attributes(foreign_keys => ids)
                  end
                end
              end
            end

            def nullify_all
              parent.transaction do
                unless foreign_keys
                  each do |record|
                    record.send("#{ foreign_key }=", nil)
                    record.send("#{ foreign_type }=", nil) if foreign_type
                  end
                else
                  parent.put_attributes(foreign_keys => [])
                end
              end
            end

        # TODO - use batch_delete!
        #
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

            def build(attributes = {})
              unless foreign_keys
                record = parent_class.new(attributes)
                record.send("#{ foreign_type }=", parent_type) if foreign_type
                record.send("#{ foreign_key }=", parent_id)
                self.push(record)
              else
                record = parent_class.new(attributes)
                ids = Array(parent.send(foreign_keys))
                ids += Array(record.id)
                parent.send("#{ foreign_keys }=", ids)
                #parent.put_attributes(foreign_keys => ids)
                self.push(record)
              end
              record
            end

            def associate(*records)
              unless foreign_keys
                Array(records).flatten.each do |record|
                  record.send("#{ foreign_type }=", parent_type) if foreign_type
                  record.send("#{ foreign_key }=", parent_id)
                  self.push(record)
                end
              else
                ids = Array(parent.send(foreign_keys))
                ids += records.map{|record| record.id}
                parent.send("#{ foreign_keys }=", ids)
                #parent.put_attributes(foreign_keys => ids)
              end
            end
            
            def <<(record)
              associate(record)
            end

            def create(attributes = {})
              created = nil
              parent.transaction do
                created = build(attributes).save
                parent.save if foreign_keys
              end
              created
            end

            def create!(attributes = {})
              created = nil
              parent.transaction do
                created = build(attributes).save!
                parent.save! if foreign_keys
              end
              created
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
                record =
                  case value
                    when Hash
                      build_#{ name }(value)
                    when Base
                      value
                  end
                #{ name }_association.set(self, record)
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
            associated = associated_class.find(:first, :conditions => conditions_for(conditions))
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

                list = #{ pluralized }()

                case value
                  when Hash
                    list.build(value)
                  when Base
                    list.associate(value)
                  when Array
                    list.associate(*value)
                end
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


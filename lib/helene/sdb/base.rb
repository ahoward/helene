module Helene
  module Sdb
    class Base
      load 'helene/sdb/base/error.rb'
      load 'helene/sdb/base/logging.rb'
      load 'helene/sdb/base/connection.rb'
      load 'helene/sdb/base/type.rb'
      load 'helene/sdb/base/types.rb'
      load 'helene/sdb/base/literal.rb'
      load 'helene/sdb/base/validations.rb'
      load 'helene/sdb/base/attributes.rb'
      load 'helene/sdb/base/associations.rb'
      load 'helene/sdb/base/transactions.rb'
      load 'helene/sdb/base/hooks.rb'

      include Attempt

      class << Base
      # track children
      #
        def subclasses
          @subclasses ||= Array.fields
        end

        def inherited(subclass)
          super
        ensure
# TODO - use class_inherited_array - etc
          subclass.domain = domain unless self==Base
          subclass.perform_virtual_consistency = perform_virtual_consistency
          subclass.hooks = hooks.dup
          key = subclass.name.blank? ? subclass.inspect : subclass.name
          subclasses[key] = subclass
        end

        def superclasses
          @superclasses ||= ancestors.select{|ancestor| ancestor <= Base and ancestor > self} 
        end

        def superclass
          @superclass ||= superclasses.first
        end

      # virtual consistency
      #
        def perform_virtual_consistency(*value)
          @perform_virtual_consistency = true unless defined?(@perform_virtual_consistency)
          @perform_virtual_consistency = !!value.first unless value.empty?
          @perform_virtual_consistency
        end

        def perform_virtual_consistency?()
          perform_virtual_consistency()
        end

        def perform_virtual_consistency=(value)
          perform_virtual_consistency(value)
        end

        def perform_virtual_consistency!()
          perform_virtual_consistency(true)
        end
        
      # domain/migration methods
      #
        def domains
          connection.list_domains[:domains]
        end

        def domain(*value)
          if value.empty?
            @domain ||= name.tableize.gsub(%r|/|, '--')
          else
            @domain = value.to_s
          end
          while @domain.size < 3
            @domain = "#{ @domain }_"
          end
          @domain
        end

        def domain=(value)
          domain(value)
        end

        def set_domain_name(value)
          domain(value)
        end

        def create_domain(*domains)
          domains.flatten!
          domains.compact!
          domains.push(domain) if domains.blank?
          domains.each do |domain|
            connection.create_domain(domain)
          end
        end

        def delete_domain(*domains)
          domains.flatten!
          domains.compact!
          domains.push(domain) if domains.blank?
          domains.each do |domain|
            connection.delete_domain(domain)
          end
        end

        def delete_all_domains!(*domains)
          domains.flatten!
          domains.compact!
          domains.push(self.domains) if domains.blank?
          domains.each do |domain|
            connection.delete_domain(domain)
          end
        end

        def delete_all
          delete_domain
          create_domain
        end

        def migrate
          create_domain
        end

        def migrate!
          delete_domain rescue nil
          create_domain
        end

        def migration
          m = Module.new{ }
          base = self
          sc =
            class << m; self; end
          sc.module_eval do
            define_method(:up){ base.migrate }
            define_method(:down){ base.delete_domain }
          end
          m
        end

      # id methods
      #
        def generate_uuid
          Util.uuid
        end

        def generate_id
          generate_uuid
        end

        def singular
          name.singularize.downcase
        end

        def plural
          name.pluralize.downcase
        end

      # create
      #
        def create(attributes={})
          record = new(attributes)
          record.before_create
          record.save
          record.after_create
          record
        end

        def create!(attributes={})
          record = new(attributes)
          record.before_create
          record.save!
          record.after_create
          record
        end

      # batch helper
      #
        def in_batches_of(*args, &block)
          options = args.extract_options!.to_options!
          size = Float(args.size > 0 ? args.shift : (options[:n] || options[:size])).to_i
          enum = args.size > 0 ? args.shift : options[:from]
          strategy = options[:strategy] || :parallel # or :serial
          threads = Float(options[:threads] || 8).to_i

          if strategy.to_s =~ %r/parallel/
            slices = [] and enum.each_slice(size){|slice| slices << slice}
            results =
              slices.threadify(threads) do |slice|
                block.call(slice)
              end
            results.flatten!
            results
          else
            results = []
            enum.each_slice(size) do |slice|
              results.push(block.call(slice))
            end
            results.flatten!
            results
          end
        end

      # batch create/update
      #
        def save_without_validation(*records)
          prepare_for_update
          sdb_attributes = ruby_to_sdb
          connection.put_attributes(domain, id, sdb_attributes, :replace)
          virtually_load(sdb_attributes)
          mark_as_old!
          errors.empty?
        end

        def batch_put(*args)
          args.flatten!
          options = args.extract_options!.to_options!
          replace = options[:replace]
          records = args.compact
          to_put = []

          records.each do |record|
            record.prepare_for_update
            item_name = record.id
            sdb_attributes = record.ruby_to_sdb
            to_put.push [item_name, sdb_attributes]
          end

          results =
            in_batches_of(25, :from => to_put) do |batch|
              items = Hash[*batch.to_a.flatten]
              connection.batch_put_attributes(domain, items, options.update(:replace => replace))
            end

          records.each do |record|
            record.virtually_load(record.ruby_to_sdb)
            record.mark_as_old!
          end

          records
        end

        def batch_save(*args)
          args.flatten!
          options = args.extract_options!.to_options!
          options[:replace] = true
          args.push options
          batch_put(*args)
        end

        def batch_create(n, options = {}, &block)
          records = nil
          Integer(n).times do |i|
            record = new(options)
            if block
              block.arity == 1 ? block.call(record) : block.call(record, i)
            end
          end
          batch_put(record)
        end

        def batch_delete(*args)
          args.flatten!
          options = args.extract_options!.to_options!
          records = args.compact
          records.each{|record| record.delete}
          args = records
          args.push options
          batch_put(*args)
        end

      # prepare attributes from sdb for ruby
      #
        def sdb_to_ruby(attributes = {})
          returning Hash.new do |hash|
            attributes.each do |key, value|
              unless value.nil? 
                type = type_for(key)
                value = type ? type.sdb_to_ruby(value) : Type.sdb_to_ruby(value) 
                hash[key.to_s] = value
              else
                hash[key.to_s] = nil
              end
            end
          end
        end

      # prepare attributes from ruby for sdb
      #
        def ruby_to_sdb(attributes = {})
          returning Hash.new do |hash|
            attributes.each do |key, value|
              unless value.nil?
                type = type_for(key)
                value = type ? type.ruby_to_sdb(value) : Type.ruby_to_sdb(value)
                hash[key.to_s] = value
              else
                hash[key.to_s] = nil
              end
            end
          end
        end

        def type_for name
          attribute = attributes.detect{|attribute| attribute.name == name.to_s}
          attribute.type if attribute
        end

      # create an existing record
      #
        def old(id, attributes = {})
          attributes = Attributes.for(attributes)
          attributes[:old] = true
          class_for(attributes).new(id, attributes)
        end

        def class_for(attributes)
          if sti_attribute
            classname = [ attributes[sti_attribute.name.to_s] ].flatten.first
            begin
              classname.blank? ? self : classname.constantize
            rescue NameError => e
              self
            end
          else
            self
          end
        end

        def sti_attribute
          @sti_attribute ||= attributes.detect{|attribute| attribute.type.sti?}
        end

      # select/find support
      #
        attr_accessor :next_token

        def select(*args, &block)
          execute_select(*args, &block)
        end
        alias_method 'find', 'select'

        def method_missing(message, *args, &block)
          re = %r/^(?:find|select)(_all)?_by_(.*)$/io
          match, all, clause = message.to_s.match(re).to_a
          super unless match
          clauses = clause.split(%r/_and_/io)
          conditions = clauses.inject(Hash.new){|hash,attr| hash.update attr => args.shift} 
          select(all ? :all : :first, :conditions => conditions)
        end

        def execute_select(*args, &block)
          log(:debug){ "execute_select <- #{ args.inspect }" }
          options = args.extract_options!.to_options!

        # yank out specical options used for recurion, formatting, and
        # following huge queries.  none of these affect sql generation
        #
          accum = options.delete(:accum) || OpenStruct.new(:items => [], :count => 0)
          raw = options.delete(:raw)
          @next_token = options.delete(:next_token)

        # handle limts > amazon's threshold specially - we'll be batching them
        #
          limit = Integer(options[:limit]) if options.has_key?(:limit)
          if limit and limit > 2500
            options[:limit] = 2500
          end
          
        # detect the arity of the result set, also set implied limit (:first)
        # and go ahead and recurse for queries that are large sets of ids
        #
          case args.first.to_s
            when "", "all"
              result_arity = -1
              wants = :all
            when "first"
              limit = 1
              result_arity = 1
              wants = :first
            else
              ids = args.flatten.compact
              raise ArgumentError, 'no ids' if ids.blank?
              if(args.first.is_a?(Array) or ids.size > 1)
                result_arity = -1
                wants = :ids
              else
                result_arity = 1
                wants = :id
              end
              if ids.size > 20
                if block
                  ids.each_slice(20){|slice| execute_select(*[slice, options], &block)}
                else
                  records = in_batches_of(20, :from => ids){|batch| execute_select(*[batch, options])}.flatten
                  return(limit ? records[0,limit] : records)
                end
              end
          end

        # generate the sql and get the results
        #
          sql = sql_for_select(*[args.dup, options.dup].flatten, &block)
          log(:debug){ "execute_select -> #{ sql.inspect }" }
          result = connection.select(sql, @next_token)
          @next_token = result[:next_token]
          items = result[:items]


        # unpack the results into models or hashes (iff :raw=>true).  iterate
        # if a block was given while doing so to prevent creating un-needed
        # objects
        #
          result[:items].each do |hash|
            item =
              unless raw
                id, attributes = hash.shift
                old(id, attributes)
              else
                hash
              end
            block ? block.call(item) : accum.items.push(item)
            accum.count += 1
            break if limit and accum.count >= limit
          end

        # if a next_token was returned handle the recursion/following
        # transparently for the user.  handle the specical case where amazon
        # says there are 'more records' even though our client limit has been
        # reached
        #
          if @next_token
            if limit.nil?
              recurse = [
                args,
                options.merge(:next_token => @next_token, :raw => raw, :accum => accum)
              ].flatten
              execute_select(*recurse, &block)
            else
              if accum.count < limit
                recurse = [
                  args,
                  options.merge(:next_token => @next_token, :raw => raw, :accum => accum, :limit => (limit - accum.count))
                ].flatten
                execute_select(*recurse, &block)
              end
            end
          end

        # finally, build the return value based on arity and limit (expecting
        # a single result or many or none when iterating)
        #
          if block
            accum.count
          else
            if result_arity == 1
              record = accum.items.first
              raise RecordNotFound if(record.nil? and wants==:id)
              record
            else
              limit ? accum.items[0,limit] : accum.items
            end
          end
        end

        def sql_for_select(*args)
          options = args.extract_options!.to_options!
          args.flatten!

        # arity
        #
          case args.first.to_s
            when "", "all"
              :all
            when "first"
              options[:limit] = 1
              :first
            else
              options[:ids] = args.flatten.compact
              args.size == 1 ? :id : :ids
          end

        # do you want to show deleted records?
        #
          want_deleted = options.has_key?(:deleted) ? options.delete(:deleted) : false

        # build select
        #
          select = sql_select_list_for(options[:select])

        # build from
        #
          from = options[:domain] || options[:from] || domain
          from = escape_domain(from)

        # build conditions
        #
          conditions = (options[:conditions] || {})
          conditions.to_options! if conditions.is_a?(Hash)
          conditions = !conditions.blank? ? " WHERE #{ sql_conditions_for(options[:conditions]) }"   : ''

        # build order
        #
          order      = !options[:order].blank? ?
            " ORDER BY #{ sort_by, sort_order = sort_options_for(options[:order]); [escape_attribute(sort_by), sort_order].join(' ') }" : ''

        # build limit
        #
          limit      = !options[:limit].blank? ? " LIMIT #{ options[:limit] }" : ''

        # build ids
        #
          ids        = options[:ids] || []

        # monkey patch conditions
        #
          unless order.blank? # you must have a predicate for any attribute sorted on...
            sort_by, sort_order = sort_options_for(options[:order])
            conditions << (conditions.blank? ? " WHERE " : " AND ") << "(#{ escape_attribute(sort_by) } IS NOT NULL)"
          end
          unless ids.blank?
            list = ids.flatten.map{|id| escape(id)}.join(',')
            conditions << (conditions.blank? ? " WHERE " : " AND ") << "ItemName() in (#{ list })"
          end
          #conditions << (conditions.blank? ? " WHERE " : " AND ") << "(deleted_at is not null and every(deleted_at) != 'nil')"
          #conditions << (conditions.blank? ? " WHERE " : " AND ") << "(every(deleted_at) = 'nil' or deleted_at is null)"
          if want_deleted
            conditions << (conditions.blank? ? " WHERE " : " AND ") << "`deleted_at`!='nil'"
          else
            conditions << (conditions.blank? ? " WHERE " : " AND ") << "`deleted_at`='nil'"
          end

        # sql
        #
          sql = "SELECT #{ select } FROM #{ from } #{ conditions } #{ order } #{ limit }".strip
        end

        ItemName = Literal.for('ItemName()') unless defined?(ItemName)
        Splat = Literal.for('*') unless defined?(Splat)

        def sql_select_list_for(*list)
          list = listify list
          list.map!{|attr| attr =~ %r/^\s*id\s*$/io ? ItemName : attr}
          sql = list.map{|attr| escape_attribute(attr)}.join(',')
          sql.blank? ? Splat : sql
        end

        def sql_conditions_for(conditions)
          sql =
            case conditions
              when Array
                sql_conditions_from_array(conditions)
              when Hash
                sql_conditions_from_hash(conditions)
              else
                conditions.respond_to?(:to_sql) ? conditions.to_sql : conditions.to_s
            end
        end

        def sql_conditions_from_array(array)
          return '' if array.blank?
          sql = ''

          case array.first
            when Hash, Array
              until array.blank?
                arg = array.shift
                sql << (
                  case arg
                    when Hash
                      "(#{ sql_conditions_from_hash(arg) })"
                    when Array
                      "(#{ sql_conditions_from_array(arg) })"
                    else
                      " #{ arg.to_s } "
                  end
                )
              end
            else
              query = array.shift.to_s
              hash = array.shift
              raise WTF unless array.empty?
              raise WTF unless hash.is_a?(Hash)

              hash.each do |key, val|
                key = key.to_s.to_sym
                sdb_val = to_condition(key, val)
                re = %r/[:@]#{ key }/
                query.gsub! re, sdb_val
              end
              sql << query
          end

          sql
        end

        def sql_conditions_from_hash(hash)
          return '' if hash.blank?
          expression = []
          every_re = %r/every\s*\(\s*([^)])\s*\)/io

          hash.each do |key, value|
            key = key.to_s

            m = every_re.match(key)
            if m
              key = m[1]
              every = true
            else
              every = false
            end

            lhs = escape_attribute(key =~ %r/^\s*id\s*$/oi ? ItemName : key)

            rhs =
              case value
                when Array
                  first = value.first.to_s.strip.downcase.gsub(%r/\s+/, ' ')
                  if(first.delete('() ') == 'every')
                    every = value.shift
                    op = value.first.to_s.strip.downcase.gsub(%r/\s+/, ' ')
                  else
                    every = false 
                    op = first
                  end
                  case op
                    when '=', '!=', '>', '>=', '<', '<=', 'like', 'not like'
                      list = value[1..-1].flatten.map{|val| to_condition(key, val)}
                      "#{ op } #{ list.join(',') }"
                    when 'between'
                      a, b, *ignored = value[1..-1].flatten.map{|val| to_condition(key, val)}
                      "between #{ a } and #{ b }"
                    when 'is null'
                      'is null'
                    when 'is not null'
                      'is not null'
                    else # 'in'
                      value.shift if op == 'in'
                      list = value.flatten.map{|val| to_condition(key, val)}
                      "in (#{ list.join(',') })"
                  end

                when Hash
                  value.to_options!
                  every = value.delete(:_every) || false
                  op = value.delete(:_op) || 'in' 
                  case op
                    when '=', '!=', '>', '>=', '<', '<=', 'like', 'not like'
                      list = value[1..-1].flatten.map{|val| to_condition(key, val)}
                      "#{ op } #{ list.join(',') }"
                    when 'between'
                      a, b, *ignored = value[1..-1].flatten.map{|val| to_condition(key, val)}
                      "between #{ a } and #{ b }"
                    when 'is null'
                      'is null'
                    when 'is not null'
                      'is not null'
                    else # 'in'
                      list = value.to_a.map{|pair| to_condition(key, pair)}
                      "in (#{ list.join(',') })"
                  end

                else
                  "= #{ to_condition(key, value) }"
              end

            lhs = "every(#{ lhs })" if every
            expression << "#{ lhs } #{ rhs }"
          end
          sql = expression.join(' AND ')
        end

        def escape_value(value)
          return value if Literal?(value)
          case value
            when TrueClass, FalseClass
              escape(value.to_s)
            else
              connection.escape(connection.ruby_to_sdb(value))
          end
        end
        alias_method 'escape', 'escape_value'

        def escape_attribute(value)
          return value if Literal?(value)
          return value if value =~ %r/^ItemName(?:\(\))?$/io
          "`#{ value.gsub(%r/`/, '``') }`"
        end

        def escape_domain(value)
          return value if Literal?(value)
          "`#{ value.gsub(%r/`/, '``') }`"
        end

        def to_condition(attribute, value)
          return value if Literal?(value)
          return value.to_condition() if value.respond_to?(:to_condition)
          type = type_for(attribute)
          value = type ? type.to_condition(value) : value
          escape_value(value)
        end

        def listify(*list)
          if list.size == 1 and list.first.is_a?(String)
            list.first.strip.split(%r/\s*,\s*/)
          else
            list.flatten!
            list.compact!
            list
          end
        end

        def sort_options_for(sort)
          return sort.to_sql if sort.respond_to?(:to_sql)
          pair =
            if sort.is_a?(Array)
              raise ArgumentError, "empty sort" if sort.empty?
              sort.push(:asc) if sort.size < 2
              sort.first(2).map{|s| s.to_s}
            else
              sort.to_s[%r/['"]?(\w+)['"]? *(asc|desc)?/io]
              [$1, ($2 || 'asc')]
            end
          [ quoted_attribute(pair.first), pair.last.to_s ]
        end

        def quoted_attribute attr
          return attr if Literal?(attr)
          if attr =~ %r/^\s*id\s*$/
            ItemName
          else
            Literal(escape_attribute(attr))
          end
        end

        def [](*ids)
          select(*ids)
        end

        def reload_if_exists(record)
          record && record.reload
        end

        def reload_all_records(*list)
          list.flatten.each{|record| reload_if_exists(record)}
        end

        def first(*args, &block)
          options = args.extract_options!.to_options!
          n = Integer(args.shift || options[:limit] || 1)
          options.to_options!
          options[:limit] = n
          order = options.delete(:order)
          if order
            sort_by, sort_order = sort_options_for(order)
            options[:order] = [sort_by, :asc]
          else
            options[:order] = [:id, :asc]
          end
          list = select(:all, options, &block)
          n == 1 ? list.first : list.first(n)
        end

        def last(*args, &block)
          options = args.extract_options!.to_options!
          n = Integer(args.shift || options[:limit] || 1)
          options.to_options!
          options[:limit] = n
          order = options.delete(:order)
          if order
            sort_by, sort_order = sort_options_for(order)
            options[:order] = [sort_by, :desc]
          else
            options[:order] = [:id, :desc]
          end
          list = select(:all, options, &block)
          n == 1 ? list.first : list.first(n)
        end

        def all(*args, &block)
          select(:all, *args, &block)
        end

        def count(conditions = {}, &block)
          conditions =
            case conditions
              when Hash, NilClass
                conditions || {}
              else
                {:conditions => conditions}
            end
          options = conditions.has_key?(:conditions) ? conditions : {:conditions => conditions}
          options[:select] = Literal('count(*)')
          sql = sql_for_select(options)
          result = connection.select(sql, &block)
          Integer(Array(result[:items].first['Domain']['Count']).first) rescue(raise(Error, result.inspect))
        end
      end

      attr_accessor 'id'
      attr_accessor 'new_record'
      alias_method 'new_record?', 'new_record'
      alias_method 'new?', 'new_record'
      attr_accessor 'attributes'
      attr_accessor 'attributes_before_sdb_to_ruby'
      alias_method 'item_name', 'id'
      attr_accessor 'deleted'
      alias_method 'deleted?', 'deleted'

      class Attributes < ::HashWithIndifferentAccess
        def Attributes.for(arg)
          Attributes === arg ? arg : new(arg)
        end
      end

    # instance methods
    #
      def initialize(*args, &block)
        @args, @block = args, block
        options = @args.extract_options!.to_options!
        @new_record = true
        @new_record = !!!options.delete(:old) if options.has_key?(:old)
        @new_record = !!!options.delete(:new_record) if options.has_key?(:new_record)
        @id = @args.size == 1 ? @args.shift : generate_id

        if @new_record
          @attributes = Attributes.new
          before_initialize
          klass.attributes.each{|attribute| attribute.initialize_record(self)}
          klass.associations.each{|association| association.initialize_record(self)}
          options.each do |name, value|
            setter = "#{ name }="
            if respond_to?(setter)
              send(setter, value)
            else
              attributes[name.to_s] = value
            end
          end
          @deleted = attributes['deleted_at'] ? true : false
          @removed = false
          after_initialize
        else
          before_load
          @attributes = Attributes.for(options)
          sdb_to_ruby!
          @deleted = attributes['deleted_at'] ? true : false
          @removed = false
          after_load
        end
      end

    # equality method
    #
      def == other
        domain == other.domain and id == other.id
      end

      def klass
        self.class
      end

      def attributes= attributes
        self.attributes.replace attributes
      end

      def generate_id
        klass.generate_id
      end

      def generate_id!
        @id = generate_id
      end

      def mark_as_old!
        self.new_record = false
      end

      def [](attribute)
        attributes[attribute.to_s]
      end

      def []=(key, value)
        attributes[key] = value
      end

      def sdb_to_ruby(attributes = self.attributes)
        klass.sdb_to_ruby(attributes)
      end

      def sdb_to_ruby!(attributes = self.attributes)
        self.attributes.replace(sdb_to_ruby(attributes))
      end

      def ruby_to_sdb(attributes = self.attributes)
        klass.ruby_to_sdb(attributes)
      end

      def ruby_to_sdb!(attributes = self.attributes)
        self.attributes.replace(ruby_to_sdb(attributes))
      end

      def reload
        check_id!
        record = attempt{ klass.select(id) || try_again! }
        raise Error, "no record for #{ id.inspect } (yet)" unless record
        replace(record)
        self
      end
      alias_method 'reload!', 'reload'

      def replace other
        self.id = other.id
        self.attributes.replace other.attributes
      end

      def raw
        klass.select(id, :raw => true)
      end

      def created_at
        Time.parse(attributes['created_at'].to_s) unless attributes['created_at'].blank?
      end
      def created_at= time
        attributes['created_at'] = time
      end

      def updated_at
        Time.parse(attributes['updated_at'].to_s) unless attributes['updated_at'].blank?
      end
      def updated_at= time
        attributes['updated_at'] = time
      end

      def deleted_at
        Time.parse(attributes['deleted_at'].to_s) unless attributes['deleted_at'].blank?
      end
      def deleted_at= time
        attributes['deleted_at'] = time
      end

      def update(options = {})
        attributes.update(options)
      end

      def raising_an_error?
        $!
      end

      def updating(&block)
        return(block.call) if(defined?(@updating) and @updating)
        @updating = true
        prepare_for_update
        before_update
        block.call
      ensure
        @updating = false
        after_update unless raising_an_error?
      end

      def save_without_validation
        updating do
          sdb_attributes = ruby_to_sdb
          connection.put_attributes(domain, id, sdb_attributes, :replace)
          virtually_load(sdb_attributes)
          mark_as_old!
          self
        end
      end

      def prepare_for_update
        time = Transaction.time.iso8601(2)
        attributes['updated_at'] = time
        if new_record?
          attributes['created_at'] ||= time
          attributes['deleted_at'] = nil
          attributes['transaction_id'] = Transaction.id
        end
      end

      def save(options = {})
        options.to_options!
        should_raise = options[:raise]
        before_save
        if(before_validation()==false)
          raise(RecordInvalid) if should_raise
          return false
        end
        unless valid?
          raise(RecordInvalid) if should_raise
          return false
        end
        after_validation()
        saved = save_without_validation
        raise(RecordNotSaved) if should_raise unless saved
        saved
      ensure
        after_save unless raising_an_error?
      end

      def save!(options = {})
        save(options.to_options.update(:raise => true))
      end

      def errors!
        raise Validations::Error.new(self, errors.message)
      end

      def update!(options = {})
        updating do
          attributes.update(options)
          save!
          virtually_save(attributes)
          self
        end
      end

      alias_method 'update_attributes', 'update!'

      def put_attributes(attributes)
        updating do
          sdb_attributes = ruby_to_sdb(attributes)
          connection.put_attributes(domain, id, sdb_attributes)
          virtually_put(sdb_attributes)
          self
        end
      end

      def save_attributes(attributes = self.attributes)
        updating do
          sdb_attributes = ruby_to_sdb(attributes)
          connection.put_attributes(domain, id, sdb_attributes, :replace)
          virtually_save(sdb_attributes)
          self
        end
      end

      def replace_attributes(attributes = self.attributes)
        updating do
          delete_attributes(self.attributes.keys)
          save_attributes(attributes)
          self
        end
      end

      def delete_attributes(*args)
        updating do
          args.flatten!
          args.compact!
          hashes, arrays = args.partition{|arg| arg.is_a?(Hash)}
          hashes.map!{|hash| stringify(hash)}
          hashes.each do |hash|
            raise ArgumentError, hash.inspect if hash.values.any?{|value| value == nil or value == []}
          end
          array = stringify(arrays.flatten)
          unless array.empty?
            array_as_hash = array.inject({}){|h,k| h.update k => nil}
            hashes.push(array_as_hash)
          end
          hashes.each{|hash|
            next if hash.empty?
            connection.delete_attributes(domain, id, hash)
            virtually_delete(hash)
          }
          self
        end
      end
      alias_method 'delete_values', 'delete_attributes'

      def delete_item
        connection.delete_item(domain, id)
        self
      ensure
        @removed = true
      end
      alias_method 'remove!', 'delete_item'

# TODO - need to consider how for pass the options along to children being
# deleted along the way - first pass with @removed/@deleted
#
      def delete(options = {})
        options.to_options!
        before_delete
        if options[:force]||options[:remove]
          delete_item
        else
          attributes['deleted_at'] = Transaction.time
          save_without_validation
        end
        self
      ensure
        @deleted = true
        after_delete unless $!
      end

      def delete!(options = {})
        delete(options.to_options.update(:force => true))
      end

      def destroy(options = {})
        before_destroy
        delete(options)
      ensure
        after_destroy unless $!
      end

    # virtual consistency
    #
      def perform_virtual_consistency(*value)
        @perform_virtual_consistency = klass.perform_virtual_consistency unless defined?(@perform_virtual_consistency)
        @perform_virtual_consistency = !!value.first unless value.empty?
        @perform_virtual_consistency
      end

      def perform_virtual_consistency?()
        perform_virtual_consistency()
      end

      def perform_virtual_consistency=(value)
        perform_virtual_consistency(value)
      end

      def perform_virtual_consistency!()
        perform_virtual_consistency(true)
      end

      def virtually_load(sdb_attributes)
        #return unless perform_virtual_consistency?
        self.attributes.replace(sdb_to_ruby(sdb_attributes))
      end

      def virtually_save(ruby_attributes=self.attributes)
        #return unless perform_virtual_consistency?
        sdb_attributes = ruby_to_sdb(ruby_attributes)
        virtually_load(sdb_attributes)
      end

      def virtually_put(sdb_attributes)
        #return unless perform_virtual_consistency?
        a = sdb_attributes
        b = ruby_to_sdb
        (a.keys + b.keys).uniq.each do |key|
          was_virtually_put = a.has_key?(key)
          if was_virtually_put
            val = b[key]
            val = [val] unless val.is_a?(Array)
            val += a[key]
          end
        end
        virtually_load(b)
      end

      def virtually_delete(ruby_attributes)
        #return unless perform_virtual_consistency?
        ruby_attributes.keys.each do |key|
          val = ruby_attributes[key]
          if val.nil?
            ruby_attributes.delete(key)
            attributes.delete(key)
          end
        end

        current = ruby_to_sdb
        deleted = ruby_to_sdb(ruby_attributes)

        deleted.each do |key, deleted_val|
          deleted_val = [ deleted_val ].flatten 
          current_val = [ current[key] ].flatten
          deleted_val.each{|val| current_val.delete(val)}

          if current[key].is_a?(Array)
            current[key] = current_val
          else
            if current_val.blank?
              current[key] = nil
            else
              current[key] = current_val
            end
          end
        end
        virtually_load(current)
      end


      def stringify(arg)
        case arg
          when Hash
            hash = {}
            arg.each{|key, val| hash[stringify(key)] = stringify(val)}
            hash
          when Array
            arg.map{|arg| stringify(arg)}
          else
            arg.to_s
        end
      end

      def listify(*list)
        klass.listify(*list)
      end

      def check_id!
        raise Error.new('No record id') unless id
      end
      
      def to_hash(options = {})
        options.to_options!
        depth = options[:depth] || 0
        if depth == 0
          attributes.to_hash
        else
          raise NotImplementedError
        end
      end

      def to_yaml
        to_hash.to_yaml
      end

      def to_json
        to_hash.to_json
      end

      def to_param
        id ? id : 'new'
      end

      def model_name
        klass.name
      end

      def domain
        klass.domain
      end

      def escape(value)
        klass.escape(value)
      end

      def sti_attribute
        klass.sti_attribute
      end
    end
  end
end

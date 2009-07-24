module Helene
  module Sdb
    class Base
      module Validations
        class Error < StandardError
          attr :object

          def initialize(object, *args, &block)
            @object = object
            args.unshift object.errors.message if args.empty?
            super(*args, &block)
          end

          def errors
            object.errors
          end
        end

        def self.included(c)
          super
          c.extend ClassMethods
        end
        
        def errors
          if(not defined?(@errors) or @errors.nil?)
            @errors ||= Errors.new(self)
          end
          @errors
        end

        def validate
          errors.clear
          self.class.validate(self)
        end

        def validate!
          errors.clear
          self.class.validate!(self)
        end

        def valid?
          validate
          errors.empty?
        end

        def errors?
          not valid?
        end

        class Errors < ::Hash
          attr_accessor :object

          class << Errors
          end

          def initialize object = nil
            @object = object
          end

          def Errors._load(string)
            new.update(Marshal.load(string))
          end

          def _dump(*a)
            Marshal.dump({}.update(to_hash))
          end
          
          def count
            size
          end
          
          def on(att)
            self[att]
          end
          
          def add(att, msg)
            (self[att] ||= []) << msg
          end
          
          def full_messages
            inject([]) do |m, kv| att, errors = *kv
              errors.each {|e| m << "#{att} #{e}"}
              m
            end
          end

          def message
            full_messages.join(' | ')
          end
        end
        
        class Validation
          def initialize(on = :save, &validation)
            @on         = (on || :save).to_sym
            @validation = validation || lambda { |o, att, v|  }
          end
          
          attr_reader :on
          
          def call(o, att, v)
            save_type = o.new_record? ? :create : :update
            @validation[o, att, v] if [:save, save_type].include?(on)
          end
          alias_method :[], :call
        end
        
        module ClassMethods
          def validations
            @validations ||= Hash.new {|h, k| h[k] = []}
          end

          def has_validations?
            !validations.empty?
          end

          def validate(o)
            if superclass.respond_to?(:validate) && !@skip_superclass_validations
              superclass.validate(o)
            end
            validations.each do |att, procs|
              v = o.send(att)
              procs.each {|p| p[o, att, v]}
            end
            o
          end

          def validate!(o)
            validate(o)
            raise Error.new(o, o.errors.message) unless o.errors.empty?
            o
          end
          
          def skip_superclass_validations
            @skip_superclass_validations = true
          end
          
          def validates_each(*atts, &block)
            options = atts.extract_options!.to_options!
            atts.each {|a| validations[a] << Validation.new(options[:on], &block)}
          end

          def validates(a, options = Hash.new, &block)
            curried = Validation.new(options[:on]) {|record, attr, value| block.call(record, value)}
            validations[a] << curried
          end

          def validates_acceptance_of(*atts)
            opts = {
              :message => 'is not accepted',
              :allow_nil => true,
              :accept => '1'
            }.merge!(atts.extract_options!)
            
            args = atts + [{:on => opts[:on]}]
            validates_each(*args) do |o, a, v|
              next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
              next if validation_skipped_by_conditions?(o, opts)
              o.errors.add(a, opts[:message]) unless v == opts[:accept]
            end
          end

          def validates_confirmation_of(*atts)
            opts = {
              :message => 'is not confirmed',
            }.merge!(atts.extract_options!)
            
            atts.each { |a| attr_accessor :"#{a}_confirmation" }
            
            args = atts + [{:on => opts[:on]}]

            validates_each(*args) do |o, a, v|
              next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
              next if validation_skipped_by_conditions?(o, opts)
              c = o.send(:"#{a}_confirmation")
              o.errors.add(a, opts[:message]) unless v == c
            end
          end

          def validates_format_of(*atts)
            opts = {
              :message => 'is invalid',
            }.merge!(atts.extract_options!)
            
            unless opts[:with].is_a?(Regexp)
              raise ArgumentError, "A regular expression must be supplied as the :with option of the options hash"
            end
            
            args = atts + [{:on => opts[:on]}]
            validates_each(*args) do |o, a, v|
              next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
              next if validation_skipped_by_conditions?(o, opts)
              o.errors.add(a, opts[:message]) unless v.to_s =~ opts[:with]
            end
          end

          def validates_length_of(*atts)
            opts = {
              :too_long     => 'is too long',
              :too_short    => 'is too short',
              :wrong_length => 'is the wrong length'
            }.merge!(atts.extract_options!)
            
            args = atts + [{:on => opts[:on]}]
            validates_each(*args) do |o, a, v|
              next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
              next if validation_skipped_by_conditions?(o, opts)
              if m = opts[:maximum]
                o.errors.add(a, opts[:message] || opts[:too_long]) unless v && v.size <= m
              end
              if m = opts[:minimum]
                o.errors.add(a, opts[:message] || opts[:too_short]) unless v && v.size >= m
              end
              if i = opts[:is]
                o.errors.add(a, opts[:message] || opts[:wrong_length]) unless v && v.size == i
              end
              if w = opts[:within]
                o.errors.add(a, opts[:message] || opts[:wrong_length]) unless v && w.include?(v.size)
              end
            end
          end

          NUMBER_RE = /^\d*\.{0,1}\d+$/ unless defined?(NUMBER_RE)
          INTEGER_RE = /\A[+-]?\d+\Z/ unless defined?(INTEGER_RE)

          def validates_numericality_of(*atts)
            opts = {
              :message => 'is not a number',
            }.merge!(atts.extract_options!)
            
            re = opts[:only_integer] ? INTEGER_RE : NUMBER_RE
            number = lambda do |value|
              Float(value) rescue Integer(value) rescue false
            end
            
            args = atts + [{:on => opts[:on]}]
            validates_each(*args) do |o, a, v|
              next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
              next if validation_skipped_by_conditions?(o, opts)
              o.errors.add(a, opts[:message]) unless number[v]
            end
          end

          def validates_presence_of(*atts)
            opts = {
              :message => 'is not present',
            }.merge!(atts.extract_options!)
            
            args = atts + [{:on => opts[:on]}]
            validates_each(*args) do |o, a, v|
              next if validation_skipped_by_conditions?(o, opts)
              o.errors.add(a, opts[:message]) unless v && !v.blank?
            end
          end

          def validation_skipped_by_conditions?(object, options)
            skipped_by_if =
              if condition = options[:if]
                !!!object.send(:instance_eval, &condition.to_proc)
              end
            skipped_by_unless =
              if condition = options[:unless]
                !!object.send(:instance_eval, &condition.to_proc)
              end
            skipped_by_if or skipped_by_unless
          end
        end
      end

      include Validations
    end
  end
end

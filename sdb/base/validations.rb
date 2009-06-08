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
            validate
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
            block = lambda{|h,k| h[k] = []}
            super(&block)
          end
          
          def on(att)
            self[att]
          end
          
          def add(att, msg)
            self[att] << msg
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
            atts.each {|a| validations[a] << block}
          end

          def validates(a, &block)
            curried = lambda{|record, attr, value| block.call(record, value)}
            validations[a] << curried
          end

          def validates_acceptance_of(*atts)
            opts = {
              :message => 'is not accepted',
              :allow_nil => true,
              :accept => '1'
            }.merge!(atts.extract_options!)
            
            validates_each(*atts) do |o, a, v|
              next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
              o.errors[a] << opts[:message] unless v == opts[:accept]
            end
          end

          def validates_confirmation_of(*atts)
            opts = {
              :message => 'is not confirmed',
            }.merge!(atts.extract_options!)
            
            validates_each(*atts) do |o, a, v|
              next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
              c = o.send(:"#{a}_confirmation")
              o.errors[a] << opts[:message] unless v == c
            end
          end

          def validates_format_of(*atts)
            opts = {
              :message => 'is invalid',
            }.merge!(atts.extract_options!)
            
            unless opts[:with].is_a?(Regexp)
              raise ArgumentError, "A regular expression must be supplied as the :with option of the options hash"
            end
            
            validates_each(*atts) do |o, a, v|
              next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
              o.errors[a] << opts[:message] unless v.to_s =~ opts[:with]
            end
          end

          def validates_length_of(*atts)
            opts = {
              :too_long     => 'is too long',
              :too_short    => 'is too short',
              :wrong_length => 'is the wrong length'
            }.merge!(atts.extract_options!)
            
            validates_each(*atts) do |o, a, v|
              next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
              if m = opts[:maximum]
                o.errors[a] << (opts[:message] || opts[:too_long]) unless v && v.size <= m
              end
              if m = opts[:minimum]
                o.errors[a] << (opts[:message] || opts[:too_short]) unless v && v.size >= m
              end
              if i = opts[:is]
                o.errors[a] << (opts[:message] || opts[:wrong_length]) unless v && v.size == i
              end
              if w = opts[:within]
                o.errors[a] << (opts[:message] || opts[:wrong_length]) unless v && w.include?(v.size)
              end
            end
          end

          NUMBER_RE = /^\d*\.{0,1}\d+$/
          INTEGER_RE = /\A[+-]?\d+\Z/

          def validates_numericality_of(*atts)
            opts = {
              :message => 'is not a number',
            }.merge!(atts.extract_options!)
            
            re = opts[:only_integer] ? INTEGER_RE : NUMBER_RE
            number = lambda do |value|
              Float(value) rescue Integer(value) rescue false
            end
            
            validates_each(*atts) do |o, a, v|
              next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
              #o.errors[a] << opts[:message] unless v.to_s =~ re
              o.errors[a] << opts[:message] unless number[v]
            end
          end

          def validates_presence_of(*atts)
            opts = {
              :message => 'is not present',
            }.merge!(atts.extract_options!)
            
            validates_each(*atts) do |o, a, v|
              o.errors[a] << opts[:message] unless v && !v.blank?
            end
          end
        end
      end

      include Validations

      def save
        valid? ? save_without_validation : false
      end

      def save!
        valid? ? save_without_validation : errors! 
      end

      def errors!
        raise Validations::Error.new(self, errors.message)
      end
    end
  end
end

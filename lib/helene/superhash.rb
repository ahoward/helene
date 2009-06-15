module Helene
  class SuperHash
    include Enumerable
    
    attr_reader :parents
    
    def initialize parents = [], default = nil
      @hash = Hash.new default
      @parents =
        case parents
          when NilClass
            []
          when Array
            parents.flatten
          else
            [parents]
        end
      @parents.each do |parent|
        raise ArgumentError, parent.class.name unless parent.respond_to?('key?')
      end
    end

    # methods that are not overrides of Hash methods
    
    def inherits_key? k
      !(@hash.key? k) && (!! @parents.find {|parent| parent.key? k } )
    end

    def own
      @hash
    end

    def own_keys
      @hash.keys
    end
    
    def owns_key? k
      @hash.key? k
    end

    # methods that override Hash methods

    def ==(other)
      return false unless other.respond_to? :size and
                          size == other.size      and
                          other.respond_to? :[]
      each { |key, value| return false unless self[key] == other[key] }
      return true
    end

    def [](key)
      fetch(key) {default}
    end
    
    def []=(key, value)
      @hash[key] = value
    end
    alias store []=
    
    def clear
      delete_if {true}
    end
    
    def default
      @hash.default
    end
    
    def default=(value)
      @hash.default = value
    end
    
    def delete(key)
      if key? key
        @hash.delete(key) do
          value = fetch(key)
          @hash[key] = default
          value
        end
      else
        block_given? ? (yield key) : default
      end
    end
    
    def delete_if
      each do |key, value|
        if yield key, value
          @hash.delete(key) { @hash[key] = default }
        end
      end
    end

    def each
      keys.each { |k| yield k, fetch(k) }
      self
    end
    alias each_pair each
    
    def each_key
      keys.each { |k| yield k }
      self
    end
      
    def each_value
      keys.each { |k| yield fetch(k) }
      self
    end
      
    def empty?
      @hash.empty? && ( not @parents.find {|parent| not parent.empty?} )
    end
    
    def fetch(*args)
      case args.size
      when 1
        key, = args
        @hash.fetch(key) {
          @parents.each do |parent|
            begin
              return parent.fetch(key)
            rescue IndexError
            end
          end
          if block_given?
            yield key
          else
            raise IndexError, "key not found"
          end
        }
      when 2
        if block_given?
          raise ArgumentError, "wrong # of arguments"
        end
        key, default_object = args
        @hash.fetch(key) {
          @parents.each do |parent|
            begin
              return parent.fetch(key)
            rescue IndexError
            end
          end
          return default_object
        }
      else
        raise ArgumentError, "wrong # of arguments(#{args.size} for 2)"
      end
    end

    def has_value? val
      each { |k,v| return true if val == v }
      return false
    end
    alias value? has_value?
    
    def index val
      each { |k,v| return k if val == v }
      return false
    end
    
    def indexes(*ks)
      ks.collect { |k| index k }
    end
    alias indices indexes
    
    def invert
      h = {}
      keys.each { |k| h[fetch(k)] = k }
      h
    end
    
    def key? k
      (@hash.key? k) || (!! @parents.find {|parent| parent.key?(k)} )
    end
    alias has_key? key?
    alias include? key?
    alias member?  key?

    def keys
      (@hash.keys + (@parents.collect { |parent| parent.keys }).flatten).uniq
    end
    
    def rehash
      @hash.rehash
      @parents.each { |parent| parent.rehash if parent.respond_to? :rehash }
      self
    end
    
    def reject
      dup.delete_if { |k, v| yield k, v }   ## or is '&Proc.new' faster?
    end
    
    def reject!
      changed = false
      
      each do |key, value|
        if yield key, value
          changed = true
          @hash.delete(key) { @hash[key] = default }
        end
      end
      
      changed ? self : nil
    end
    
    def replace hash
      @hash.replace hash
      @parents.replace []
    end
    
    class ParentImmutableError < StandardError; end
    
    def shift
      if @hash.empty?
        raise ParentImmutableError, "Attempted to shift data out of parent"
      else
        @hash.shift
      end
    end
    
    def size
      keys.size
    end
    alias length size
    
    def sort
      if block_given?
        to_a.sort { |x, y| yield x, y }   ## or is '&Proc.new' faster?
      else
        to_a.sort
      end
    end
    
    def to_a
      to_hash.to_a
    end
    
    def to_hash
      h = {}
      keys.each { |k| h[k] = fetch(k) }
      h
    end
    
    def to_s
      to_hash.to_s
    end
    
    def update h
      @hash.update h
      self
    end
      
    def values
      keys.collect { |k| self[k] }
    end

  end
end

class Class
private
  def class_superhash(*vars)
    for var in vars
      class_eval %{
        @#{var} = Hash.new
        def self.#{var}
          @#{var} ||= SuperHash.new(superclass.#{var})
        end
      }
    end
  end

  # A superhash of key-value pairs in which the value is a superhash
  # which inherits from the key-indexed superhash in the superclass.
  def class_superhash2(*vars)
    for var in vars
      class_eval %{
        @#{var} = Hash.new
        def self.#{var}(arg = nil)
          @#{var} ||= SuperHash.new(superclass.#{var})
          if arg
            if self == #{self.name}
              unless @#{var}.has_key? arg
                @#{var}[arg] = Hash.new
              end
            else
              unless @#{var}.owns_key? arg
                @#{var}[arg] = SuperHash.new(superclass.#{var}(arg))
              end
            end
            @#{var}[arg]
          else
            @#{var}
          end
        end
      }
    end
  end
end

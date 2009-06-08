module Helene
  module Sdb
    module Cast
      def self.export m
        module_function m
        public m
      end

      List = []

      def self.cast m, &b
        define_method m, &b
        export m
        List << m.to_s
      end

      cast :boolean do |obj|
        obj = [obj].flatten.first.to_s
        case obj
          when %r/^(true|t|1)$/ 
            true
          when %r/^(false|f|0)$/ 
            false
          else
            !!obj
        end
      end

      cast :integer do |obj|
        obj = [obj].flatten.first.to_s
        Integer(obj)
      end

      cast :float do |obj|
        obj = [obj].flatten.first.to_s
        Float(obj)
      end

      cast :number do |obj|
        obj = [obj].flatten.first.to_s
        Float(obj) rescue Integer(obj)
      end

      cast :string do |obj|
        obj = [obj].flatten.first.to_s
        String(obj)
      end

      cast :symbol do |obj|
        obj = [obj].flatten.first.to_s
        String(obj).to_sym
      end

      cast :uri do |obj|
        require 'uri'
        obj = [obj].flatten.first.to_s
        ::URI.parse(obj)
      end

      cast :time do |obj|
        require 'time'
        obj = [obj].flatten.first.to_s
        ::Time.parse(obj)
      end

      cast :date do |obj|
        obj = [obj].flatten.first.to_s
        require 'date'
        ::Date.parse(obj)
      end

      cast :list do |*objs|
        [*objs].flatten.join(',').split(/,/)
      end

# add list_of_xxx methods
      List.dup.each do |type|
        next if type.to_s =~ %r/list/ 
        m = "list_of_#{ type }"
        define_method m do |*objs|
          list(*objs).map{|obj| send type, obj}
        end
        export m 
        List << m
      end

# add list_of_xxx_from_file
      List.dup.each do |type|
        next if type.to_s =~ %r/list/ 
        m = "list_of_#{ type }"
        define_method m do |*objs|
          list(*objs).map{|obj| send type, obj}
        end
        export m 
        List << m
      end

      def Cast.for(sym)
        prefix = sym.to_s.downcase.to_sym
        candidates = List.select{|m| m =~ %r/^#{ prefix }/i}
        m = candidates.shift
        raise ArgumentError, "unsupported cast: #{ sym.inspect } (#{ List.join ',' })" unless
          m
        raise ArgumentError, "ambiguous cast: #{ sym.inspect } (#{ List.join ',' })" unless
          candidates.empty? or m.to_s == sym.to_s
        this = self
        lambda{|obj| method(m).call obj}
      end
      def self.[] sym
        Cast.for(sym)
      end
    end
  end
end

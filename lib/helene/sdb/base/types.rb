module Helene
  module Sdb
    class Base
      class Type
        type(:string){
          ruby_to_sdb do |value|
            value.to_s
          end

          sdb_to_ruby do |value|
            Array(value).first.to_s
          end
        }

# TODO - this should be auto generated (for all types!)

=begin
        type(:list_of_string){
          ruby_to_sdb do |value|
            Type.listify(value)
          end

          sdb_to_ruby do |value|
            Type.listify(value)
          end
        }
=end

        type(:timestamp){
          ruby_to_sdb do |value|
            Time.parse(value.to_s).utc.iso8601(2)
          end

          sdb_to_ruby do |value|
            Time.parse(Array(value).first.to_s).localtime
          end
        }

        type(:boolean){
          ruby_to_sdb do |value|
            (!!value).to_s
          end

          sdb_to_ruby do |value|
            Array(value).first.to_s =~ %r/^\s*t/i ? true : false
          end
        }

        type(:number){
          ruby_to_sdb do |value|
            number = Integer(value.to_s)
            raise ArgumentError, "(#{ name } = #{ number.inspect }) < 0" if number < 0
            INT_FMT % number
          end

          sdb_to_ruby do |value|
            Integer(Array(value).first.to_s.sub(%r/^[0-]+/,''))
          end
        }

        type(:integer){
          ruby_to_sdb do |value|
            number = Integer(value.to_s)
            offset = number + Type::INT_OFF
            if(offset < 0 || offset.class != Fixnum)
              raise(
                ArgumentError,
                "(#{ name } = #{ number.inspect } (offset=#{ offset })) too small"
              )
            end
            INT_FMT % offset
          end

          sdb_to_ruby do |array|
            offset = Integer([array].flatten.first.to_s.sub(%r/^[0-]+/,''))
            number = offset - Type::INT_OFF
          end
        }

        type(:sti){
          ruby_to_sdb do |value|
            value.to_s
          end

          sdb_to_ruby do |value|
            Array(value).first.to_s
          end
        }

        type(:url){
          ruby_to_sdb do |value|
            value.to_s.sub(%r{\A(?!\w+:)(?=\S)}, "http://")
          end

          sdb_to_ruby do |value|
            Array(value).first.to_s
          end
        }
      end
    end
  end
end

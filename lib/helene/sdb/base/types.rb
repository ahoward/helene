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

        type(:text){
          ruby_to_sdb do |value|
            chunks = value.to_s.scan(%r/.{1,1019}/) # 1024 - '1024:'.size
            i = -1
            fmt = '%04d:'
            chunks.map!{|chunk| [(fmt % (i += 1)), chunk].join}
            raise ArgumentError, 'that is just too big yo!' if chunks.size >= 256
            chunks
          end

          sdb_to_ruby do |value|
            chunks =
              Array(value).flatten.map do |chunk|
                index, text = chunk.split(%r/:/, 2)
                [Float(index).to_i, text]
              end
            chunks.replace chunks.sort_by{|index, text| index}
            chunks.map!{|index, text| text}.join
          end
        }
      end
    end
  end
end

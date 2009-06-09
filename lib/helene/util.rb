module Helene
  module Util
    def homedir
      homedir =
        catch :home do
          ["HOME", "USERPROFILE"].each do |key|
            throw(:home, ENV[key]) if ENV[key]
          end
          if ENV["HOMEDRIVE"] and ENV["HOMEPATH"]
            throw(:home, "#{ ENV['HOMEDRIVE'] }:#{ ENV['HOMEPATH'] }")
          end
          File.expand_path("~") rescue(File::ALT_SEPARATOR ? "C:/" : "/")
        end
      File.expand_path homedir
    end

    def unindent! s
      indent = nil
      s.each do |line|
        next if line =~ %r/^\s*$/
        indent = line[%r/^\s*/] and break
      end
      s.gsub! %r/^#{ indent }/, "" if indent
      s
    end

    def unindent s
      unindent! "#{ s }"
    end

    def indent! s, n = 2
      n = Integer n
      margin = ' ' * n
      unindent! s
      s.gsub! %r/^/, margin
      s
    end

    def indent s, n = 2
      indent!(s.to_s.dup, n)
    end

    def inline! s
      s.gsub! %r/\n/, ' '
      s.squeeze! ' '
      s
    end

    def inline s
      inline!(s.dup)
    end

    def random_string options = {}
      options.to_options!

      Kernel.srand

      default_chars = ( ('a' .. 'z').to_a + ('A' .. 'Z').to_a + (0 .. 9).to_a )
      %w( 0 O l ).each{|char| default_chars.delete(char)}

      default_size = 6

      chars = options[:chars] || default_chars
      size = Integer(options[:size] || default_size)
   
      Array.new(size).map{ chars[rand(2**32)%chars.size, 1] }.join
    end

    def snake_case(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end

    def camel_case(lower_case_and_underscored_word, first_letter_in_uppercase = true)
      if first_letter_in_uppercase
        lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      else
        camel_case(lower_case_and_underscored_word).sub(%r/^(.)/){ $1.downcase }
      end
    end

    def normalize!(s)
      s.to_s.gsub!(%r/\s/, ' ')
      s
    end

    def number_for(arg)
      arg = arg.to_s
      arg.gsub! %r/^[0\s]+/, ''
      Integer(arg) rescue Float(arg)
    end

    def compress(data)
      writer = Zlib::GzipWriter.new(StringIO.new(result=''))
      writer.write(data.to_s)
      writer.close
      result
    end

    def decompress(data)
      Zlib::GzipReader.new(StringIO.new(data.to_s)).read
    end

    def encode(data)
      Base64.encode64(compress(data))
    end

    def decode(data)
      decompress(Base64.decode64(data.to_s))
    end

    extend self
  end
end

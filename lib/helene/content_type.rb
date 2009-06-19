module Helene
  module ContentType
    unless defined?(@config)
      @config = File.join(File.dirname(__FILE__), 'content_type.yml')
      @table = YAML.load(IO.read(@config))
    end

    def for(ext)
      @table[ext] || @table[ext.split(%r/[.]/).last.strip.downcase]
    end
    alias_method '[]', 'for'

    extend self
  end
end

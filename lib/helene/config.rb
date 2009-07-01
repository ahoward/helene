module Helene
  class Config
    class << Config
      def for(arg)
        config = new
        updates =
          case arg
            when Hash
              arg
            when NilClass
              {}
            else
              if arg.respond_to?(:read)
                YAML.load(arg.read)
              else
                YAML.load(IO.read(arg.to_s))
              end
          end
        config.update(updates)
        config
      end

      def default_path
        File.join(Helene::Util.homedir, '.helene.yml')
      end

      def default
        @default ||= (
          update_from_env(
            begin
              Config.for(default_path)
            rescue Errno::ENOENT
              Config.for(nil)
            end
          )
        )
      end

      def update_from_env config
        keys_for(:ACCESS_KEY_ID).each do |key|
          value_for(key) do |value|
            config.access_key_id = value
          end
        end

        keys_for(:SECRET_ACCESS_KEY).each do |key|
          value_for(key) do |value|
            config.secret_access_key = value
          end
        end

        keys_for(:CA_FILE).each do |key|
          value_for(key) do |value|
            config.ca_file = value
          end
        end

        config
      end

      def keys_for key
        key = key.to_s.strip.upcase
        [key, "AWS_#{ key }", "HELENE_#{ key }"]
      end

      def value_for key
        if Object.const_defined?(key)
          return yield(Object.const_get(key))
        end
        if ENV[key]
          return yield(ENV[key])
        end
      end

      def normalized hash
        stringified_keys(hash)
      end

      def stringified_keys hash
        hash.keys.inject(Hash.new){|h,k| h.update(k.to_s => hash.fetch(k))}
      end
    end

    attr :config

    def initialize options = {}
      @config = {}
      options.each do |key, value|
        msg = "#{ key }="
        if respond_to?(msg)
          send msg, value
        else
          @config[key.to_s] = value
        end
      end
    end

    alias_method 'to_hash', 'config'

    def to_yaml(*args, &block)
      to_hash.to_yaml(*args, &block)
    end

    %w( access_key_id secret_access_key ca_file ).each do |key|
      code = <<-__
        def #{ key }= #{ key }
          config['#{ key }'] = #{ key }.to_s
        end
        def #{ key }
          config['#{ key }'].to_s
        end
      __
      module_eval(code)
    end

    def inspect
      config.inspect
    end

    def normalize!
      config.replace normalized
    end

    def normalized hash = config
      Config.normalized(hash)
    end

    def [] key
      config[key.to_s]
    end
    alias_method 'get', '[]'

    def []= key, val
      config[key.to_s] = val
    end
    alias_method 'set', '[]='

    def has_key? key
      config.has_key? key.to_s
    end

    def update hash
      config.update normalized(hash)
      self
    end

    def method_missing m, *a, &b
      key, setter = m.to_s.split(/(=)/)
      if setter
        val = a.first
        return(set(key, val))
      end
      if has_key?(key)
        return(get(key))
      end
      super
    end
  end
end


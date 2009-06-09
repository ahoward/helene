module Helene
  class Config
    def Config.for(arg)
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

    def Config.default_path
      File.join(Helene::Util.homedir, '.helene.yml')
    end

    def Config.default
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

    def Config.update_from_env config
=begin
      username = ENV['GNIP_USERNAME']
      password = ENV['GNIP_PASSWORD']
      auth = ENV['GNIP_AUTH']
      if(auth and not (username and password))
        username, password = auth.split(%r/:/, 2)
      end
      uri = ENV['GNIP_URI'] || Helene.default.uri
      config.username = username if username
      config.password = password if password
      config.uri = uri if uri
      config
=end
    end

    def Config.normalized hash
      stringified_keys(hash)
    end

    def Config.stringified_keys hash
      hash.keys.inject(Hash.new){|h,k| h.update(k.to_s => hash.fetch(k))}
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

    def username= username
      config['username'] = username.to_s
    end
    def username
      config['username'].to_s
    end

    def password= password
      config['password'] = password.to_s
    end
    def password
      config['password'].to_s
    end

    def uri= uri
      config['uri'] = uri.to_s
    end
    def uri
      URI.parse(config['uri'].to_s) if config['uri']
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


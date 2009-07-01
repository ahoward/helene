module Helene
  class << Helene
    %w( access_key_id secret_access_key ca_file ).each do |setting|
      code = <<-__
        def #{ setting }()
          Config.default.#{ setting }
        end
        def #{ setting }=(value)
          Config.default.#{ setting }=value
        end
      __
      eval(code)
    end
  end
end

module Helene
  if defined?(Rails)
  # allow configuration of in a rails project to be defined in
  # config/helene.rb
  #
    if rails?
      config = rails_root('config', 'helene.rb')
      Kernel.load(config) if test(?s, config)
    end

  # register Sdb::Base::RecordNotFound with rails's exception handling
  #
    ActionController
    ActionController::Base
    ActionController::Base.rescue_responses.update({
      'Helene::Sdb::Base::RecordNotFound' => :not_found,
      'Helene::Sdb::Base::RecordInvalid' => :unprocessable_entity,
      'Helene::Sdb::Base::RecordNotSaved' => :unprocessable_entity,
    })
  end
end

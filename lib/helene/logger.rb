module Helene
  class << Helene
    def logger
      @logger ||= nil
    end

    def logger= logger
      @logger = logger.respond_to?(:debug) ? logger : logger_factory.new(logger)
    end

    def logger_for(*args, &block) 
      defined?(Logging) ? Logging.logger(*args, &block) : Logger.new(*args, &block)
    end

    def log(*args, &block)
      logger.send(*args, &block) if logger
    end
  end

  Helene.logger = defined?(Rails) ? Rails.logger : Helene.logger_for(STDERR)
end

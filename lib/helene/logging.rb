module Helene
  class << Helene
    def logger
      @logger ||= nil
    end

    def logger= logger
      @logger = logger.respond_to?(:debug) ? logger : logger_for(logger)
    end

    def logger_for(*args, &block) 
      defined?(Logging) ? Logging.logger(*args, &block) : Logger.new(*args, &block)
    end

    def log(*args, &block)
      logger.send(*args, &block) if logger
    end

    def default_logger
      begin
        if defined?(Rails)
          Rails.logger
        else
          if((helene_log = ENV['HELENE_LOG']))
            case helene_log.to_s.downcase.strip
              when 'stderr'
                Helene.logger_for(STDERR)
              when 'stdout'
                Helene.logger_for(STDOUT)
              else
                begin
                  Helene.logger_for open(helene_log, 'a+')
                rescue
                  Helene.logger_for open(helene_log, 'w+')
                end
            end
          else
            # null = test(?e, '/dev/null') ? '/dev/null' : 'NUL'
            # Helene.logger_for open(null, 'w+')
            NullLogger
          end
        end
      rescue Object
        NullLogger
      end
    end
    module NullLogger
      def respond_to?(*a, &b) true end
      def method_missing(m, *a, &b) end
      extend self
    end
  end

  Helene.logger = Helene.default_logger
end

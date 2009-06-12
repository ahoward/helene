module Helene
  module Attempt
    class TooMany < StandardError; end

    def attempt(*args, &block)
      options = args.extract_options!.to_options!

      retries = Integer(args.shift || options[:retries] || 42)
      label = String(args.shift || options[:label] || caller.first(1))
      exceptions = [options[:rescue] || StandardError].flatten
      result = nil
      attempts = 0
      sleepcycle = options[:sleepcycle] || options[:backoff] || SleepCycle.new
      Thread.current[:attempt_label] = label

      loop do
        caught =
          begin
            catch(label) do
              result = yield(attempts += 1)
            end
          rescue *exceptions => e
            #STDERR.puts Util.emsg(e)
            raise if options[:rescue]==false
            sleep(sleepcycle.next)
            :try_again
          end

        break unless caught == :try_again
        raise TooMany, "#{ retries } (#{ label })" if attempts >= retries
      end

      result
    end 

    def try_again! label = Thread.current[:attempt_label]
      throw label, :try_again
    end

    def give_up! label = Thread.current[:attempt_label]
      throw label, :give_up
    end

    extend self
  end
end

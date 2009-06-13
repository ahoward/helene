module Helene
  module Sdb
    class Base
      HOOKS = [
        :before_initialize,
        :after_initialize,
        :before_create,
        :after_create,
        :before_update,
        :after_update,
        :before_validation,
        :after_validation,
        :before_save,
        :after_save,
        :before_destroy,
        :after_destroy
      ] unless defined?(HOOKS)

      class << Base
        # Some fancy code generation here in order to define the hook class methods...
        unless defined?(HOOK_METHOD_STR)
          HOOK_METHOD_STR = <<-__ 
            def Base.%s(method = nil, &block)
              unless block
                (raise Error, 'No hook method specified') unless method
                block = proc {send method}
              end
              add_hook(%s, &block)
            end
          __
        end
        
        def def_hook_method(m) #:nodoc:
          instance_eval(HOOK_METHOD_STR % [m.to_s, m.inspect])
        end
        
        # Returns the hooks hash for the model class.
        def hooks #:nodoc:
          @hooks ||= Hash.new {|h, k| h[k] = []}
        end

        def hooks= hooks
          @hooks = hooks
        end
        
        def add_hook(hook, &block) #:nodoc:
          chain = hooks[hook]
          chain << block
          define_method(hook) do 
            return false if super == false
            chain.each {|h| break false if instance_eval(&h) == false}
          end
        end

        # Returns true if the model class or any of its ancestors have defined
        # hooks for the given hook key. Notice that this method cannot detect 
        # hooks defined using overridden methods.
        #def has_hooks?(key)
          #has = hooks[key] && !hooks[key].empty?
          #has || ((self != Base) && superclass.has_hooks?(key))
        #end
      end

      HOOKS.each {|h| define_method(h) {}}
      HOOKS.each {|h| def_hook_method(h)}
    end
  end
end

require 'chef/resource/lwrp_base'

class Chef
module Provisioning
module AWSDriver
  class SuperLWRP < Chef::Resource::LWRPBase
    #
    # Add the :default lazy { ... } and :coerce validation_opts to `attribute`
    #
    if self.respond_to?(:properties)
      # in Chef 12.5+, properties replace attributes and these respond to
      # coerce and default with a lazy block - no need for overwriting!
    else
      def self.attribute(attr_name, validation_opts={})
        if validation_opts[:default].is_a?(Chef::DelayedEvaluator)
          lazy_default = validation_opts.delete(:default)
        end
        coerce = validation_opts.delete(:coerce)
        if lazy_default || coerce
          define_method(attr_name) do |arg=nil|
            arg = instance_exec(arg, &coerce) if coerce && !arg.nil?

            result = set_or_return(attr_name.to_sym, arg, validation_opts)

            if result.nil? && arg.nil?
              result = instance_eval(&lazy_default) if lazy_default
            end

            result
          end
          define_method(:"#{attr_name}=") do |arg|
            if arg.nil?
              remove_instance_variable(:"@#{arg}")
            else
              set_or_return(attr_name.to_sym, arg, validation_opts)
            end
          end
        else
          super
        end
      end

      # Below chef 12.5 you cannot do `default lazy: { ... }` - this adds that
      def self.lazy(&block)
        Chef::DelayedEvaluator.new(&block)
      end
    end

  end
end
end
end

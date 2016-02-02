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

    # copy from Chef 12.5 params_validate.rb at http://redirx.me/?t35q.
    if !method_defined?(:_pv_is)
      def _pv_is(opts, key, to_be, raise_error: true)
        return true if !opts.has_key?(key.to_s) && !opts.has_key?(key.to_sym)
        value = _pv_opts_lookup(opts, key)
        to_be = [ to_be ].flatten(1)
        to_be.each do |tb|
          case tb
          when Proc
            return true if instance_exec(value, &tb)
          when Property
            validate(opts, { key => tb.validation_options })
            return true
          else
            return true if tb === value
          end
        end

        if raise_error
          raise ::Chef::Exceptions::ValidationFailed, "Option #{key} must be one of: #{to_be.join(", ")}!  You passed #{value.inspect}."
        else
          false
        end
      end
    end
  end
end
end
end

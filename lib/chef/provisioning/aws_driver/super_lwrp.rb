require 'chef/resource/lwrp_base'

class Chef
module Provisioning
module AWSDriver
  class SuperLWRP < Chef::Resource::LWRPBase
    #
    # Add the :lazy_default and :coerce validation_opts to `attribute`
    #
    def self.attribute(attr_name, validation_opts={})
      lazy_default = validation_opts.delete(:lazy_default)
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

    # FUUUUUU cloning - this works for Chef 11 or 12.1
    def load_prior_resource(*args)
      Chef::Log.debug "Overloading #{self.resource_name} load_prior_resource with NOOP"
    end
  end
end
end
end

module NoResourceCloning
  def prior_resource
    # For some unknown reason, `kind_of?` is just not working
    if resource_class <= Chef::Provisioning::AWSDriver::SuperLWRP
      Chef::Log.debug "Canceling resource cloning for #{resource_class}"
      nil
    else
      super
    end
  end
  def emit_cloned_resource_warning; end
  def emit_harmless_cloning_debug; end
end

# Chef 12.2 changed `load_prior_resource` logic to be in the Chef::ResourceBuilder class
# but that class only exists in 12.2 and up
if defined? Chef::ResourceBuilder
  # Ruby 2.0.0 has prepend as a protected method
  Chef::ResourceBuilder.send(:prepend, NoResourceCloning)
end

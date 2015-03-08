require 'chef/resource/lwrp_base'

class Chef
  module Provisioning
    module AWSDriver
      class SuperLWRP < Chef::Resource::LWRPBase
        #
        # Add the :default_block and :coerce options to `attribute`
        #
        def self.attribute(attr_name, *validation_opts)
          options = {}
          validation_opts.each { |o| options.merge(o) }

          lazy_default = options.delete(:lazy_default)
          coerce = options.delete(:coerce)
          if lazy_default || convert
            define_method(attr_name) do |arg=nil|
              arg = instance_exec(coerce, arg) if coerce && !arg.nil?

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

        def self.default(&block)
          { lazy_default: block }
        end

        def self.coerce(&block)
          { coerce: block }
        end
      end
    end
  end
end

require 'cheffish/rspec/recipe_run_wrapper'

module AWSSupport
  class AWSResourceRunWrapper < Cheffish::RSpec::RecipeRunWrapper
    def initialize(example, resource_type, name, &properties)
      super(example.chef_config) do
        if properties && properties.parameters.size > 0
          public_send(resource_type, name) { instance_exec(example, &properties) }
        else
          public_send(resource_type, name, &properties)
        end
      end
      @example = example
      @resource_type = resource_type
      @name = name
      @properties = properties
    end

    attr_reader :example
    attr_reader :resource_type
    attr_reader :name

    def resource
      resources.first
    end

    def to_s
      "#{resource_type}[#{name}]"
    end

    def destroy
      resource_type = self.resource_type
      name = self.name
      example.recipe do
        public_send(resource_type, name) do
          if allowed_actions.include?(:purge)
            action :purge
          else
            action :destroy
          end
        end
      end.converge
    end

    def aws_object
      resource.aws_object
    end
  end
end

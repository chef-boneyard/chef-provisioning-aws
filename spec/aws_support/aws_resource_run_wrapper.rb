require 'cheffish/rspec/recipe_run_wrapper'

module AWSSupport
  class AWSResourceRunWrapper < Cheffish::RSpec::RecipeRunWrapper
    def initialize(rspec_context, resource_type, name, &properties)
      super(rspec_context.chef_config) do
        public_send(resource_type, name, &properties)
      end
      @rspec_context = rspec_context
      @resource_type = resource_type
      @name = name
      @properties = properties
    end

    attr_reader :rspec_context
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
      rspec_context.run_recipe do
        public_send(resource_type, name) do
          action :purge
        end
      end
    end

    def aws_object
      resource.aws_object
    end
  end
end

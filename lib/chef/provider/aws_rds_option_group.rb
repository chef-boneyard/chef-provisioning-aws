require 'chef/resource/aws_resource'
require 'chef/provider/aws_provider'

class Chef::Provider::AwsRdsOptionGroup < Chef::Provider::AwsProvider

  action :create do
    fail "Can't create an option group without a description" if new_resource.description.nil?
    fail "Can't create an option group without an engine name" if new_resource.engine_name.nil?
    fail "Can't create an option group without a major engine version" if new_resource.major_engine_version.nil?

    if existing_option_group == nil
        creation_options = {
            :option_group_name => new_resource.name,
            :engine_name => new_resource.engine_name,
            :major_engine_version => new_resource.major_engine_version,
            :option_group_description => new_resource.description
        }

        converge_by "Creating new RDS option group" do
            new_driver.rds.client.create_option_group(creation_options)
            new_resource.save
        end

        converge_by "Setting options for RDS option group" do
            modification_options = {
                :option_group_name => new_resource.name,
                :options_to_include => new_resource.options,
                :options_to_remove => [],
                :apply_immediately => new_resource.apply_immediately || false
            }
            new_driver.rds.client.modify_option_group(modification_options)
        end
    end
  end

  def existing_option_group
    @existing_option_group ||= begin
        response = new_driver.rds.client.describe_option_groups(option_group_name: new_resource.name)
        response[:option_groups_list].first
    rescue
        nil
    end
  end

end

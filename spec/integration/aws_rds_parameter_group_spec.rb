require 'spec_helper'

describe Chef::Resource::AwsRdsParameterGroup do
  extend AWSSupport
  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do

    with_aws "no required pre-existing objects" do
      it "creates an empty parameter group" do
        expect_recipe {
          aws_rds_parameter_group "test-db-parameter-group" do
            db_parameter_group_family "postgres9.4"
            description "testing provisioning"
          end
        }.to create_an_aws_rds_parameter_group("test-db-parameter-group",
                                               :db_parameter_group_family => "postgres9.4",
                                               :description => "testing provisioning"
                                              )
      end

      it "creates a parameter group with tags" do
        expect_recipe {
          aws_rds_parameter_group "test-db-parameter-group-with-tags" do
            db_parameter_group_family "postgres9.4"
            description "testing provisioning"
            aws_tags key1: 'value'
          end
        }.to create_an_aws_rds_parameter_group("test-db-parameter-group-with-tags")
              .and have_aws_rds_parameter_group_tags("test-db-parameter-group-with-tags",
                                                     {
                                                       'key1' => 'value'
                                                     }
                                                    )
      end

      it "creates an new parameter group with parameters" do
        results = nil
        expect_recipe {
          results = aws_rds_parameter_group "test-db-parameter-group-with-parameters" do
            db_parameter_group_family "postgres9.4"
            description "testing provisioning"
            parameters [{:parameter_name => "max_connections", :parameter_value => "250", :apply_method => "pending-reboot"}]
          end
        }.to create_an_aws_rds_parameter_group("test-db-parameter-group-with-parameters",
                                               :db_parameter_group_family => "postgres9.4",
                                               :description => "testing provisioning",
                                              )

        expect(results.parameters).to eq([{:parameter_name => "max_connections", :parameter_value => "250", :apply_method => "pending-reboot"}])
        results.parameters.each do |parameter|
          expect(parameter[:parameter_value]).to eq("250") if parameter[:parameter_name] == "max_connections"
        end
      end

      context "when the object is updated" do
        let(:final_max_connection_value)   { "300" }
        let(:final_application_name_value) { "second_name" }
        let(:initial_parameters) { [
                                     {:parameter_name => "application_name", :parameter_value => "first_name", :apply_method => "pending-reboot"}
                                   ] }
        let(:updated_parameters) { [
                                     {:parameter_name => "application_name", :parameter_value => final_application_name_value, :apply_method => "pending-reboot"},
                                     {:parameter_name => "max_connections", :parameter_value => final_max_connection_value, :apply_method => "pending-reboot"}
                                   ] }
        it "updates properly" do
          results = nil
          expect_recipe {
            results = aws_rds_parameter_group "test-db-parameter-group-updated" do
              db_parameter_group_family "postgres9.4"
              description "testing provisioning"
              parameters initial_parameters
            end
          }
          expect(results.parameters).to eq(initial_parameters)

          results_2 = nil
          expect_recipe {
            results_2 = aws_rds_parameter_group "test-db-parameter-group-updated" do
              db_parameter_group_family "postgres9.4"
              description "testing provisioning"
              parameters updated_parameters
            end
          }
          expect(results_2.parameters).to eq(updated_parameters)
          results_2.parameters.each do |parameter|
            expect(parameter[:parameter_value]).to eq(final_max_connection_value) if parameter[:parameter_name] == "max_connections"
            expect(parameter[:parameter_value]).to eq(final_application_name_value) if parameter[:parameter_name] == "application_name"

          end
        end
      end
    end
  end
end

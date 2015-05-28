require 'spec_helper'

describe "AWS Tagged Items" do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do
      it "aws_ebs_volume 'test_volume' created with default Name tag" do
        expect_recipe {
          aws_ebs_volume "test_volume"
        }.to create_an_aws_ebs_volume('test_volume'
        ).and have_aws_ebs_volume_tags('test_volume',
                       { 'Name' => 'test_volume' }
        ).and be_idempotent
      end

      it "aws_ebs_volume 'test_volume' tags are updated" do
        expect_recipe {
          aws_ebs_volume "test_volume_a" do
            aws_tags :byebye => 'true'
          end
        }.to create_an_aws_ebs_volume('test_volume_a'
        ).and have_aws_ebs_volume_tags('test_volume_a',
                                      { 'Name' => 'test_volume_a',
                                        'byebye' => 'true'
                                      }
        ).and be_idempotent

        expect_recipe {
          aws_ebs_volume "test_volume_a" do
            aws_tags 'Name' => 'test_volume_b', :project => 'X'
          end
        }.to update_an_aws_ebs_volume('test_volume_a'
        ).and have_aws_ebs_volume_tags('test_volume_a',
                                      { 'Name' => 'test_volume_b',
                                        'project' => 'X'
                                      }
        ).and be_idempotent
      end

      it "aws_ebs_volume 'test_volume' tags are not changed when not updated" do
        expect_recipe {
          aws_ebs_volume "test_volume_c" do
            aws_tags :byebye => 'true'
          end
        }.to create_an_aws_ebs_volume('test_volume_c'
        ).and have_aws_ebs_volume_tags('test_volume_c',
                                      { 'Name' => 'test_volume_c',
                                        'byebye' => 'true'
                                      }
        ).and be_idempotent

        expect_recipe {
          aws_ebs_volume "test_volume_c"
        }.to have_aws_ebs_volume_tags('test_volume_c',
                                      { 'Name' => 'test_volume_c',
                                        'byebye' => 'true'
                                      }
        ).and be_idempotent
      end


      it "aws_ebs_volume 'test_volume' created with new Name tag" do
        expect_recipe {
          aws_ebs_volume "test_volume_2" do
            aws_tags :Name => 'test_volume_new'
          end
        }.to create_an_aws_ebs_volume('test_volume_2'
        ).and have_aws_ebs_volume_tags('test_volume_2',
                                      { 'Name' => 'test_volume_new' }
        ).and be_idempotent
      end

      it "aws_ebs_volume 'test_volume' created with custom tag" do
        expect_recipe {
          aws_ebs_volume "test_volume_3" do
            aws_tags :project => 'aws-provisioning'
          end
        }.to create_an_aws_ebs_volume('test_volume_3'
        ).and have_aws_ebs_volume_tags('test_volume_3',
                                      { 'Name' => 'test_volume_3',
                                        'project' => 'aws-provisioning'
                                      }
        ).and be_idempotent
      end

      it "aws_instance 'test_instance' created with custom tag", :super_slow do
        expect_recipe {
          machine 'test_instance' do
            action :allocate
          end
        }.to create_an_aws_instance('test_instance')

        expect_recipe {
          aws_instance "test_instance" do
            aws_tags :project => 'FUN'
          end
        }.to update_an_aws_instance('test_instance'
        ).and have_aws_instance_tags('test_instance',
                                      { 'Name' => 'test_instance',
                                        'project' => 'FUN'
                                      }
        ).and be_idempotent
      end

      it "machine 'test_machine' created using machine_options aws_tag", :super_slow do
        expect_recipe {
          machine 'test_machine' do
            machine_options :aws_tags => { :mach_opt_sym => 'value', 'mach_opt_str' => 'value' }
            action :allocate
          end
        }.to create_an_aws_instance('test_machine'
        ).and have_aws_instance_tags('test_machine',
                                      { 'Name' => 'test_machine',
                                        'mach_opt_sym' => 'value',
                                        'mach_opt_str' => 'value'
                                      }
        ).and be_idempotent
      end

      it "machine 'test_machine_2' created using default with_machine_options aws_tag", :super_slow do
        expect_recipe {
          with_machine_options :aws_tags => { :default => 'value1' }

          machine 'test_machine_2' do
            action :allocate
          end
        }.to create_an_aws_instance('test_machine_2'
        ).and have_aws_instance_tags('test_machine_2',
                                      { 'Name' => 'test_machine_2',
                                        'default' => 'value1'
                                      }
        ).and be_idempotent
      end

      it "load balancer 'lbtest' tagged with load_balancer_options" do
        expect_recipe {
          load_balancer 'lbtest' do
            load_balancer_options :aws_tags => { :marco => 'polo', 'happyhappy' => 'joyjoy' },
                                  :availability_zones => ["#{driver.aws_config.region}a", "#{driver.aws_config.region}b"] # TODO should enchance to accept letter AZs
          end
        }.to create_an_aws_load_balancer('lbtest'
        ).and have_aws_load_balancer_tags('lbtest',
                                            { 'marco' => 'polo',
                                              'happyhappy' => 'joyjoy'
                                            }
        ).and be_idempotent
        expect_recipe {
          load_balancer 'lbtest' do
            load_balancer_options :aws_tags => { :default => 'value1' }
          end
        }.to update_an_aws_load_balancer('lbtest'
        ).and have_aws_load_balancer_tags('lbtest',
                                            { 'default' => 'value1' }
        ).and be_idempotent
      end

      it "does not error when a class does not define #aws_tags" do
        expect_recipe {
          aws_eip_address 'test_address'
        }.to create_an_aws_eip_address('test_address')
      end

    end
  end
end

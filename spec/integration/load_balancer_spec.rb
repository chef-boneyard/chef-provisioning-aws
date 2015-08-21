describe "load_balancer" do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do

      it "creates load_balancer tags" do
        expect_recipe {
          load_balancer 'test-load-balancer' do
            aws_tags key1: "value"
            load_balancer_options :availability_zones => ['us-east-1d']
          end
        }.to create_an_aws_load_balancer('test-load-balancer')
        .and have_aws_load_balancer_tags('test-load-balancer',
          {
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        load_balancer 'test-load-balancer' do
          aws_tags key1: "value"
          load_balancer_options :availability_zones => ['us-east-1d']
        end

        it "updates aws_load_balancer tags" do
          expect_recipe {
            load_balancer 'test-load-balancer' do
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_load_balancer_tags('test-load-balancer',
            {
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_load_balancer tags" do
          expect_recipe {
            load_balancer 'test-load-balancer' do
              aws_tags Hash.new
            end
          }.to have_aws_load_balancer_tags('test-load-balancer',
            Hash.new
          ).and be_idempotent
        end
      end

    end
  end
end

describe 'aws_ebs_volume' do
  def run_recipe(recipe)
    cwd = Dir.pwd
    Dir.chdir(File.dirname(__FILE__))
    begin
      system("bundle exec chef-client -z -o aws_ebs_volume_fixture::#{recipe}")
    ensure
      Dir.chdir(Dir.pwd)
    end
  end

  before(:all) do
    run_recipe 'setup'
  end

  it 'creates a volume' do
    run_recipe 'create'
  end

  it 'attaches a volume' do
    run_recipe 'attach'
  end

  it 'detaches a volume' do
    run_recipe 'detach'
  end

  it 'deletes a volume' do
    run_recipe 'delete'
  end

  after(:all) do
    run_recipe 'teardown'
  end
end

source "https://rubygems.org"

gemspec

gem "chef"
gem "rb-readline"

gem "chef-zero", ">= 4.0"
gem "chefstyle", "~> 0.10.0"
gem "rake"
gem "rspec", "~> 3.0"
gem "simplecov"

group :debug do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
end

instance_eval(ENV["GEMFILE_MOD"]) if ENV["GEMFILE_MOD"]

# If you want to load debugging tools into the bundle exec sandbox,
# add these additional dependencies into Gemfile.local
eval_gemfile(__FILE__ + ".local") if File.exist?(__FILE__ + ".local")

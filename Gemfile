source 'https://rubygems.org'

gemspec

gem 'durham_rails', path: File.expand_path("../../durham_rails", __FILE__)
gem 'schmit_api', path: File.expand_path("../../schmit/schmit_api", __FILE__)

# gem 'simplecov', :require => false, :group => :test

test_app_gemfile_path = File.expand_path("../test_app/Gemfile", __FILE__)
if File.exists?(test_app_gemfile_path)
  instance_eval (File.read(test_app_gemfile_path).lines.select do |line|
    !(line.index('trifle') || line.index('source') || line.index('durham_rails') || line.index('schmit'))
  end).join("\n")
end

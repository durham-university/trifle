$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "trifle/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "trifle"
  s.version     = Trifle::VERSION
  s.authors     = ["Olli Lyytinen"]
  s.email       = ["olli.lyytinen@durham.ac.uk"]
  s.homepage    = "https://source.dur.ac.uk/university-library/trifle"
  s.summary     = "Triple I F Loader and Editor"
  s.description = "Triple I F Loader and Editor."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", "~> 4.2.5.1"
  s.add_dependency 'sass-rails', '~> 5.0'
  s.add_dependency 'jquery-rails'
  s.add_dependency 'jquery-ui-rails'

  s.add_dependency 'bootstrap-sass', '~> 3.3.5'
  s.add_dependency 'bootstrap-sass-extras'

  s.add_dependency 'simple_form', '~> 3.1.0'
  s.add_dependency 'kaminari'
  
  s.add_dependency 'iiif-presentation'

  s.add_dependency 'rsolr', '~> 1.0.6'
  s.add_dependency 'active-fedora'
  s.add_dependency 'active_fedora-noid'

  s.add_dependency 'hydra-pcdm', '0.3.1'
  s.add_dependency 'hydra-works', '0.6.0'
  s.add_dependency 'hydra-editor', '~> 1.1.0'

  s.add_dependency 'durham_rails', '~> 0.0.7'

  s.add_dependency 'devise'
  s.add_dependency 'devise_ldap_authenticatable'
  s.add_dependency 'cancancan', '~> 1.10'

  s.add_dependency 'nokogiri'

  s.add_dependency 'resque'
  s.add_dependency 'resque-pool'

  s.add_development_dependency "sqlite3"
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'factory_girl_rails'
  s.add_development_dependency 'database_cleaner'
    s.add_development_dependency 'ladle'

end

$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "trifle/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "trifle"
  s.version     = Trifle::VERSION
  s.authors     = ["Olli Lyytinen"]
  s.email       = ["olli.lyytinen@durham.ac.uk"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of Trifle."
  s.description = "TODO: Description of Trifle."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "rails", "~> 4.2.5.1"

  s.add_development_dependency "sqlite3"
end

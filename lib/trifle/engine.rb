module Trifle
  class Engine < ::Rails::Engine
    isolate_namespace Trifle

    config.autoload_paths += %W(#{config.root}/app/jobs/concerns #{config.root}/app/actors/concerns #{config.root}/app/forms/concerns #{config.root}/app/presenters/concerns)

    initializer "trifle.noid_translators" do |app|
      DurhamRails::Noid.set_active_fedora_translators
    end

    initializer "trifle.inflections" do |app|
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.acronym 'IIIF'
      end
    end

    initializer "trifle.assets.precompile" do |app|
      app.config.assets.precompile += %w( trifle/logo.png trifle/trifleAnnotationEndpoint.js )
    end

    config.generators do |g|
      g.test_framework      :rspec,        :fixture => false
      g.fixture_replacement :factory_girl, :dir => 'spec/factories'
      g.assets false
      g.helper false
    end
  end
end

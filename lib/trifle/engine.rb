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
        inflect.irregular 'canvas', 'canvases'
      end
    end

    initializer "trifle.assets.precompile" do |app|
      app.config.assets.precompile += %w( trifle/logo.png trifle/trifleAnnotationEndpoint.js )
    end
    
    initializer "trifle.route_shortcuts" do |app|
      # Trifle routes are organised based on IIIF recommended URI patterns where
      # everything belonging to a manifest is under path including the manifest id.
      # DurhamRails framework however doesn't generally use parent objects in paths.
      # This block adds some route helper shortcuts so that the route helpers DurhamRails
      # uses work with Trifle routes. It essentially converts helpers like
      # iiif_image_path(image) to iiif_manifest_iiif_image_path(image.manifest,image)
      Trifle::Engine.routes.named_routes.url_helpers_module.module_eval do
        {
          'iiif_image' => ['','edit_','new_'],
          'iiif_image_iiif' => [''],
          'iiif_image_annotation_iiif' => [''],
          'iiif_annotation_list' => ['','edit_'],
          'iiif_annotation_list_iiif' => [''],
          'iiif_annotation' => ['','edit_'],
          'iiif_annotation_iiif' => [''],
          'iiif_annotation_list_iiif_annotation' => ['new_'],
          'iiif_annotation_list_iiif_annotations' => [''],
          'iiif_range' => ['','edit_','new_'],
          'iiif_range_iiif' => [''],
          'iiif_range_iiif_range' => ['new_'],
          'iiif_range_iiif_ranges' => [''],
          'iiif_image_iiif_annotation_lists' => [''],
          'iiif_image_iiif_annotation_list' => ['new_'],
          'iiif_image_all_annotations' => [''],
          'iiif_image_iiif_layers' => [''],
          'iiif_image_iiif_layer' => ['new_'],
          'iiif_layer' => ['','edit_'],
        }.each do |suffix,prefixes|
          prefixes.each do |prefix|
            ['_url','_path'].each do |mode|
              define_method(:"#{prefix}#{suffix}#{mode}") do |*objs_and_options|
                send(:"#{prefix}iiif_manifest_#{suffix}#{mode}",objs_and_options.first.manifest,*objs_and_options)
              end
            end
          end
        end
      end
    end

    config.generators do |g|
      g.test_framework      :rspec,        :fixture => false
      g.fixture_replacement :factory_girl, :dir => 'spec/factories'
      g.assets false
      g.helper false
    end

  end
end

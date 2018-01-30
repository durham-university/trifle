module Trifle
  class IIIFLayersController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'

    def create
      set_resource( new_resource(resource_params) )
      if @resource.valid?
        @parent.layers.push(@resource) if @parent
      end

      saved = false
      if @resource.valid?
        saved = @resource.save # this triggers save in manifest
      end

      create_reply(saved)
    end

    protected

    def self.presenter_terms
      super + [:description, :image_location, :image_source, :embed_xywh]
    end

    def self.form_terms
      super + [:width, :height]
    end

    def new_resource(params={})
      self.class.model_class.new(@parent, params)
    end

    def set_parent
      @parent = IIIFImage.find(params[:iiif_image_id])
    end
  end
end

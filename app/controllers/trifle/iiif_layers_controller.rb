module Trifle
  class IIIFLayersController < Trifle::ApplicationController
    before_action :set_convert_to_image_resource, only: [:convert_to_image]
    
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

    def convert_to_image
      authorize!(:edit, @resource)
      authorize!(:edit, @resource.parent)
      authorize!(:destroy, @resource)
      authorize!(:edit, @resource.manifest)

      actor = Trifle::LayersActor.new(@resource)
      new_image = actor.make_layer_an_image
      success = new_image.present?

      respond_to do |format|
        if success
          format.html { redirect_to new_image, notice: "Layer converted to image" }
          format.json { render json: { resource: new_image.as_json, status: 'ok'} }
        else
          format.html { 
            flash[:error] = "Unable to convert layer to image"
            redirect_to @resource
          }
          format.json { render json: { resource: @resource.as_json, status: 'error', message: "Unable to convert layer to image"} }
        end
      end            
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

    def set_convert_to_image_resource
      set_resource
    end
  
  end
end

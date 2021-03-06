module Trifle
  class IIIFRangesController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'

    def create
      set_resource( new_resource(resource_params) )
      if @resource.valid?
        if @parent.is_a?(Trifle::IIIFManifest)
          @parent.ranges.push(@resource) if @parent
        else
          @parent.sub_ranges.push(@resource) if @parent
        end
      end

      saved = false
      if @resource.valid?
        saved = @resource.save # this triggers save in manifest
      end

      create_reply(saved)
    end    

    protected

    def new_resource(params={})
      manifest = if @parent.is_a?(Trifle::IIIFManifest)
        @parent
      else
        @parent.manifest
      end
      self.class.model_class.new(manifest, params.except(:canvas_ids)).tap do |res|
        res.send(:canvas_ids=,params[:canvas_ids],@parent) if params[:canvas_ids].present?
      end
    end

    def self.presenter_terms
      super + [:canvases]
    end
    
    def set_parent
      if params[:iiif_range_id].present?
        @parent = IIIFRange.find(params[:iiif_range_id])
      else
        @parent = IIIFManifest.find(params[:iiif_manifest_id])
      end
    end
        
    def self.edit_form_class
      EditForm
    end

    class EditForm < DurhamRails::GenericForm.form_class_for(model_class, form_terms)
      def self.build_permitted_params
        super.tap do |params|
          params.delete({canvases: []})
          params << {canvas_ids: []}
        end
      end
      
      def self.reflect_on_association(*args)
        model_class.reflect_on_association(*args)
      end
      
      def canvas_ids
        self.model.canvas_ids
      end
    end
  end
end

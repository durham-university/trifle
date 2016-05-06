module Trifle
  class IIIFRangesController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'

    protected

    def new_resource(params={})
      self.class.model_class.new(params.except(:canvas_ids)).tap do |res|
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

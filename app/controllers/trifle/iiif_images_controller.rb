module Trifle
  class IIIFImagesController < Trifle::ApplicationController
    before_action :set_all_annotations_resource, only: [:all_annotations]
    
    include DurhamRails::ModelControllerBase
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'
        
    before_action :set_annotation_iiif_resource, only: [:show_annotation_iiif]
        
    def all_annotations
      annotations = @resource.annotation_lists.map(&:annotations).flatten
      render json: (annotations.map do |a|
        a.to_iiif.to_ordered_hash
      end)
    end

    def show_annotation_iiif
      annotation = @resource.iiif_annotation
      render json: annotation.to_json(pretty: true)
    end    

    def self.presenter_terms
      super + [:identifier, :image_location, :image_source]
    end
    
    def self.form_terms
      super - [:image_source]
    end

    def set_parent
      @parent = IIIFManifest.find(params[:iiif_manifest_id])
    end

    protected
    
      def new_resource(params={})
        super(params).tap do |res|
          res.set_ark_naan(@parent.local_ark_naan) if @parent
        end
      end


    private
      def set_all_annotations_resource
        set_resource
      end
      def set_annotation_iiif_resource
        set_resource
      end
      def authorize_resource!
        return true if params[:action].to_sym == :show_annotation_iiif
        return super
      end

  end
end

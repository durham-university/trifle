module Trifle
  class IIIFImagesController < Trifle::ApplicationController
    before_action :set_all_annotations_resource, only: [:all_annotations]
    
    include DurhamRails::ModelControllerBase
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'
        
    def all_annotations
      annotations = @resource.annotation_lists.map(&:annotations).flatten
      render json: (annotations.map do |a|
        a.to_iiif.to_ordered_hash
      end)
    end

    def self.presenter_terms
      super + [:identifier, :image_location]
    end

    def set_parent
      @parent = IIIFManifest.find(params[:iiif_manifest_id])
    end

    private
      def set_all_annotations_resource
        set_resource
      end

  end
end

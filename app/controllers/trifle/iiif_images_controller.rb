module Trifle
  class IIIFImagesController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase

    helper 'trifle/application'

    def self.presenter_terms
      super + [:identifier, :image_location]
    end

    def set_parent
      @parent = IIIFManifest.find(params[:iiif_manifest_id])
    end

  end
end

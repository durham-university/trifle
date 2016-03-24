module Trifle
  class IIIFAnnotationListsController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'

    def set_parent
      @parent = IIIFImage.find(params[:iiif_image_id])
    end

  end
end

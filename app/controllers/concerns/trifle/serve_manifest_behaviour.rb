module Trifle
  module ServeManifestBehaviour
    extend ActiveSupport::Concern

    included do
      before_action :set_manifest_resource, only: [:manifest]
    end
    
    def manifest
      render json: @resource.iiif_manifest.to_json(pretty: true)
    end
    
    private
      def set_manifest_resource
        set_resource
      end
      
      def authorize_resource!
        return true if params[:action].to_sym == :manifest
        return super
      end
    
  end
end

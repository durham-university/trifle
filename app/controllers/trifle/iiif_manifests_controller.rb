module Trifle
  class IIIFManifestsController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include Trifle::ImageDepositBehaviour
    include Trifle::ServeIIIFBehaviour
    include Trifle::AllowCorsBehaviour # Keep this last

    helper 'trifle/application'

    def self.presenter_terms
      super + [:identifier,  :image_container_location, :date_published, :author, :description, :json_file, :licence, :attribution]
    end

    def set_parent
    end
    
    def index
      if params['format'] == 'json' && params['mirador'] == 'true'
        resources = Trifle::IIIFManifest.all.from_solr!
        render json: (resources.map do |res|
          {manifestUri: trifle.iiif_manifest_iiif_url(res), location: Trifle.mirador_location }
        end)
      else
        super
      end  
    end
    
    def authenticate_user!(opts={})
      return true if params[:action].to_sym == :index && params['format'] == 'json' && params['mirador'] == 'true'
      return super
    end
    def authorize_resource!
      return true if params[:action].to_sym == :index && params['format'] == 'json' && params['mirador'] == 'true'
      return super
    end
    
    private 
      def set_cors_headers?
        return true if params[:action].to_sym == :index && params['format'] == 'json' && params['mirador'] == 'true'
        return super
      end
    
  end
end

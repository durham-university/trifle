module Trifle
  module ServeIIIFBehaviour
    extend ActiveSupport::Concern

    included do
      before_action :set_iiif_resource, only: [:show_iiif]
    end
    
    def show_iiif
      render json: @resource.to_iiif(use_cached: true).to_json(pretty: true)
    end
    
    private
      def set_iiif_resource
        @resource = self.class.model_class.load_instance_from_solr(params[:id])
        self.instance_variable_set(:"@#{self.class.model_name.element}",@resource)
      end
      
      def authorize_resource!
        return true if params[:action].to_sym == :show_iiif
        return super
      end
    
      def set_cors_headers?
        return true if params[:action].to_sym == :show_iiif
        return super
      end
    
  end
end

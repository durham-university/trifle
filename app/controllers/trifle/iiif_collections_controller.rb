module Trifle
  class IIIFCollectionsController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include Trifle::ServeIIIFBehaviour
    include Trifle::AutoPublishResourceBehaviour
    include Trifle::AllowCorsBehaviour # Keep this last

    helper 'trifle/application'

    def self.presenter_terms
      super + [:identifier,  :description, :attribution, :licence]
    end

    def set_parent
      if params[:iiif_collection_id].present?
        @parent = Trifle::IIIFCollection.find(params[:iiif_collection_id])
      end
    end
    
    def show_iiif
      if params['mirador'] == 'true'
        resources = Trifle::IIIFManifest.all_in_collection(@resource)
        render json: (resources.map do |res|
          {manifestUri: trifle.iiif_manifest_iiif_url(res), location: Trifle.mirador_location }
        end)
      else
        super
      end  
    end
    
    def show
      if params['full_manifest_list'].present?
        authorize!(:index_all, Trifle::IIIFManifest)
        resources = Trifle::IIIFManifest.all_in_collection(@resource.root_collection)
        render json: {resources: (resources.map do |res| res.as_json end), page: 1, total_pages: 1}
      elsif params['full_collection_list'].present?
        authorize!(:index_all, Trifle::IIIFCollection)
        resources = Trifle::IIIFCollection.all_in_collection(@resource.root_collection)
        render json: {resources: (resources.map do |res| res.as_json end), page: 1, total_pages: 1}
      else
        super
      end
    end
    
        
    protected
    
      def index_resources
        if @parent.present?
          @parent.sub_collections
        else
          Trifle::IIIFCollection.root_collections
        end
      end
    
      def use_paging?
        false
      end
    
  end
end

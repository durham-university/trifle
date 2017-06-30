module Trifle
  class MiradorController < Trifle::ApplicationController
    before_action :authenticate_user!
    before_action :set_resource
    before_action :authorize_resource!
    
    def show
      @resource.try(:ancestors_from_solr!)
      
      @collection = @resource.root_collection
      case @resource
      when Trifle::IIIFManifest
        @manifest = @resource
        @image = nil
        if params['page'].present?
          page = params['page'].to_i-1
          @image = @manifest.images[page] if page >= 0 && page < @manifest.images.count
        end
      when Trifle::IIIFImage
        @image = @resource
        @manifest = @image.parent
      when Trifle::IIIFCollection
        @manifest = nil
        @image = nil
      else
          raise 'Resource must be either a collection, a manifest or an image'
      end
      @use_annotations = @manifest && can?(:update,@manifest)
      @use_toc = @manifest && can?(:update_ranges,@manifest)
      @no_auto_load = true if params['no_auto_load']
      render :show, layout: false
    end
    
#    def index
#      @no_auto_load = true if params['no_auto_load']
#      render :show, layout: false
#    end

    protected
    
    def authorize_resource!
      authorize!(:show_mirador, @resource)
    end
    def set_resource(resource = nil)
      if resource
        @resource = resource
      else
        @resource = ActiveFedora::Base.load_instance_from_solr(params['id'])
      end
    end
  end
end

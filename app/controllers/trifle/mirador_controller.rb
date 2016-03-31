module Trifle
  class MiradorController < Trifle::ApplicationController
    def show
      @resource = ActiveFedora::Base.find(params['id'])
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
      @no_auto_load = true if params['no_auto_load']
      render :show, layout: false
    end
    
    def index
      @no_auto_load = true if params['no_auto_load']
      render :show, layout: false
    end
  end
end

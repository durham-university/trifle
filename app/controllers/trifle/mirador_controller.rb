module Trifle
  class MiradorController < Trifle::ApplicationController
    def show
      @resource = ActiveFedora::Base.find(params['id'])
      raise 'Resource must be either a manifest or a collection' unless (@resource.is_a?(Trifle::IIIFManifest) || @resource.is_a?(Trifle::IIIFCollection))
      @no_auto_load = true if params['no_auto_load']
      render :show, layout: false
    end
    
    def index
      @no_auto_load = true if params['no_auto_load']
      render :show, layout: false
    end
  end
end

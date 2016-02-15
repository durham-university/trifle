module Trifle
  class MiradorController < Trifle::ApplicationController
    def show
      @resource = Trifle::IIIFManifest.find(params['id'])
      @no_auto_load = true if params['no_auto_load']
      render :show, layout: false
    end
    
    def index
      @no_auto_load = true if params['no_auto_load']
      render :show, layout: false
    end
  end
end

module Trifle
  class IIIFAnnotationListsController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'
    
    def create
      set_resource( new_resource(resource_params) )
      if @resource.valid?
        @parent.annotation_lists.push(@resource) if @parent
      end

      saved = false
      if @resource.valid?
        saved = @resource.save # this triggers save in parent
      end

      create_reply(saved)
    end    

    protected
    
    def preload_show
      super
      @resource.ancestors_from_solr!
    end
    
    def set_parent
      @parent = IIIFImage.find(params[:iiif_image_id])
    end
      
    def new_resource(params={})
      self.class.model_class.new(@parent, params)
    end
    
  end
end

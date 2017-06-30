module Trifle
  class IIIFAnnotationsController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'
    
    def create
      set_resource( new_resource(resource_params) )
      if @resource.valid?
        @parent.annotations.push(@resource) if @parent
      end

      saved = false
      if @resource.valid?
        if !@parent.persisted?
          @parent.parent.annotation_lists.push(@parent)
          @parent.assign_id! if @parent && !@parent.persisted?
        end
        saved = @resource.save # this triggers save in image
      end

      create_reply(saved)
    end    
    
    
    protected
    
    def preload_show
      super
      @resource.ancestors_from_solr!
    end
    
    def update_reply(success)
      return super(success) unless params[:reply_iiif]=='true'
      render json: @resource.to_iiif.to_json
    end
    
    def create_reply(success)
      return super(success) unless params[:reply_iiif]=='true'
      render json: @resource.to_iiif.to_json
    end

    def self.presenter_terms
      super + [:content, :format, :language, :selector]
    end

    def set_parent
      if params.key?(:iiif_image_id)
        parent_image = IIIFImage.find(params[:iiif_image_id])
        @parent = parent_image.annotation_lists.first || IIIFAnnotationList.new(parent_image, title: 'Default annotation list')
      else
        @parent = IIIFAnnotationList.find(params[:iiif_annotation_list_id])
      end
    end

    def new_resource(params={})
      self.class.model_class.new(@parent, params)
    end

  end
end

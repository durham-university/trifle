module Trifle
  class IIIFAnnotationsController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'
    
    protected
    
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
        @parent = parent_image.annotation_lists.first || begin
          IIIFAnnotationList.new.tap do |al|
            al.title = 'Default annotation list'
            al.instance_variable_set(:@parent_image, parent_image)
            class << al
              def save
                return false unless super
                unless @parent_image.ordered_members.to_a.include?(self)
                  @parent_image.ordered_members << self
                  @parent_image.save
                else
                  true
                end
              end
            end
          end
        end
      else
        @parent = IIIFAnnotationList.find(params[:iiif_annotation_list_id])
      end
    end

  end
end

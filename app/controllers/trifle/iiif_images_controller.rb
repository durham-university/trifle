module Trifle
  class IIIFImagesController < Trifle::ApplicationController
    before_action :set_all_annotations_resource, only: [:all_annotations]
    
    include DurhamRails::ModelControllerBase
    include Trifle::RefreshFromSourceBehaviour
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'
        
    before_action :set_annotation_iiif_resource, only: [:show_annotation_iiif]
    before_action :set_show_parent, only: [:show]
        
    def all_annotations
      annotations = @resource.annotation_lists.map(&:annotations).flatten
      render json: (annotations.map do |a|
        a.to_iiif.to_ordered_hash
      end)
    end

    def show_annotation_iiif
      annotation = @resource.iiif_annotation
      render json: annotation.to_json(pretty: true)
    end    

    def self.presenter_terms
      super + [:identifier, :description, :image_location, :image_source, :source_record]
    end
    
    def self.form_terms
      super - [:image_source]
    end

    def set_parent
      @parent = IIIFManifest.find(params[:iiif_manifest_id])
    end
    def set_show_parent
      @parent = IIIFManifest.load_instance_from_solr(params[:iiif_manifest_id])
      @resource.has_parent!(@parent)
      @parent.ancestors_from_solr!
      # the previous/next links require parent.ordered_members, getting them from
      # solr dramatically improves performance
      @parent.ordered_members.from_solr!
    end

    def index_resources
      return super if @parent && !params['in_source'].present?
      raise 'Only in_source indexing supported for all images' if !params['in_source'].present?
      
      from = self.class.model_class.find_from_source(params["in_source"],params.fetch('in_source_prefix','true')=='true')
      if use_paging? && params['per_page'] != 'all'
        per_page = [[params.fetch('per_page', 20).to_i, 100].min, 5].max
        page = [params.fetch('page', 1).to_i, 1].max
        self.class.resources_for_page(page: page, per_page: per_page, from: from)
      else
        from
      end
    end


    protected
    
      def new_resource(params={})
        super(params).tap do |res|
          res.set_ark_naan(@parent.local_ark_naan) if @parent
        end
      end


    private
      def set_all_annotations_resource
        @resource = self.class.model_class.load_instance_from_solr(params[:id])
      end
      def set_annotation_iiif_resource
        @resource = self.class.model_class.load_instance_from_solr(params[:id])
      end
      def authorize_resource!
        return true if params[:action].to_sym == :show_annotation_iiif
        return super
      end

  end
end

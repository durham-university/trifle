module Trifle
  class IIIFImagesController < Trifle::ApplicationController
    before_action :set_all_annotations_resource, only: [:all_annotations]
    before_action :set_convert_to_layer_resource, only: [:convert_to_layer]
    
    include DurhamRails::ModelControllerBase
    include Trifle::RefreshFromSourceBehaviour
    include Trifle::LinkMillenniumBehaviour
    include Trifle::ServeIIIFBehaviour

    helper 'trifle/application'
        
    before_action :set_annotation_iiif_resource, only: [:show_annotation_iiif]
    before_action :set_show_parent, only: [:show]
    

    def convert_to_layer
      authorize!(:edit, @resource)
      target_images = Array.wrap(params[:target_id]).map do |id| Trifle::IIIFImage.find(id) end
      target_images.each do |image|
        authorize!(:edit, image)
        authorize!(:destroy, image)
      end

      actor = Trifle::LayersActor.new(@resource)
      success = actor.make_images_layers(target_images)

      respond_to do |format|
        if success
          format.html { redirect_to @resource, notice: "Image converted to layer" }
          format.json { render json: { resource: @resource.as_json, status: 'ok'} }
        else
          format.html { 
            flash[:error] = "Unable to convert image to layer"
            redirect_to @resource
          }
          format.json { render json: { resource: @resource.as_json, status: 'error', message: "Unable to convert image to layer"} }
        end
      end      
    end

    def update
      if params[:iiif_image][:layer_order].present?
        # Can't use MemberReordering concern because layers are not in ordered_members
        reorder_layers(params[:iiif_image][:layer_order])
      end
      super
    end    
    
        
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

      def reorder_layers(params_order)
        split = params_order.split(/[\r\n]+/)
        new_item_ids = split.uniq
        return false if new_item_ids.length != split.length

        old_layers = @resource.layers
        return false if new_item_ids.length != old_layers.length
        new_layers = new_item_ids.map do |new_id|
          old_layers.find do |l| l.id == new_id end
        end
        return false if new_layers.include?(nil)

        @resource.layers.replace(new_layers)
        @resource.serialise_layers
        true      
      end

      def preload_show
        super
        @resource.parent.try(:ordered_members).try(:from_solr!)
      end
      
    
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
      def set_convert_to_layer_resource
        set_resource
      end
      def authorize_resource!
        return true if params[:action].to_sym == :show_annotation_iiif
        return super
      end

  end
end

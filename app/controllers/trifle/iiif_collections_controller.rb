module Trifle
  class IIIFCollectionsController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include DurhamRails::SelectableResourceBehaviour
    include DurhamRails::ReceiveMovesBehaviour
    include Trifle::ServeIIIFBehaviour
    include Trifle::AutoPublishResourceBehaviour
    include Trifle::MemberReordering
    include Trifle::AllowCorsBehaviour # Keep this last

    helper 'trifle/application'

    def self.presenter_terms
      super + [:digitisation_note, :identifier,  :description, :source_record, :licence, :attribution, :logo, :keeper]
    end

    def set_parent
      if params[:iiif_collection_id].present?
        @parent = Trifle::IIIFCollection.find(params[:iiif_collection_id])
      end
    end
    
    def show_iiif
      if params['mirador'] == 'true'
        @resource.ordered_members.from_solr!
        render json: (@resource.manifests.map do |res|
          {manifestUri: trifle.iiif_manifest_iiif_url(res), location: @resource.inherited_keeper || Trifle.mirador_location }
        end)
      elsif params['mirador'] == 'collection'
        render json: [{collectionContent: @resource.to_iiif(use_cached: true).to_ordered_hash}]
      else
        super
      end  
    end
    
    def index_iiif
      render json: Trifle::IIIFCollection.index_collection_iiif(use_cached: true).to_json(pretty: true)
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
    
    def update
      if params[:iiif_collection][:manifest_order].present?
        raise 'Invalid manifest list' unless reorder_members(params[:iiif_collection][:manifest_order], Trifle::IIIFManifest)
      end
      if params[:iiif_collection][:sub_collection_order].present?
        raise 'Invalid sub collection list' unless reorder_members(params[:iiif_collection][:sub_collection_order], Trifle::IIIFCollection)
      end
      super
    end    
    
    def move_selection_into
      # Need to publish all containers which changed due to resource move and
      # all moved resources (they link to their container). Also need to update
      # solr of the moved resources and everything under them 
      # (links to root container).
      
      # This hook will only work if bucket is emptied on successful move.
      raise 'Assert error, empty_bucket_after_move? must be true' unless empty_bucket_after_move?
      
      moved_resources = {}
      changed = {}
      
      selection_bucket.from_fedora!.each do |res|
        changed[res.id] ||= res
        moved_resources[res.id] ||= res
        res.ordered_by.each do |parent|
          changed[parent.id] ||= parent
        end
        # The destination container gets updated as part of the update jobs of the
        # moved resources.
      end
      
      super
      
      if changed.any? && !selection_bucket.any?
        changed.values.each do |res|
          job = Trifle::PublishJob.new(resource: res)
          job.validate_job!
          job.queue_job
        end
        moved_resources.values.each do |res|
          if res.is_a?(Trifle::IIIFManifest)
            res.update_index
          else
            # Collections need indexes updated recursively, do in a job due to
            # potentially very large number of updates needed.
            job = Trifle::UpdateIndexJob.new(resource: res, recursive: true)
            job.validate_job!
            job.queue_job
          end
        end
      end
    end
        
    protected
    
      def validate_move
        return false unless super
        selection_bucket.each do |res|
          unless res.is_a?(Trifle::IIIFManifest) || res.is_a?(Trifle::IIIFCollection)
            error_message = "Can only move manifests in a collection"
            respond_to do |format|
              format.html { flash[:error] = error_message ; redirect_to @resource }
              format.json { render json: { status: 'error', message: error_message } }
            end          
            return false
          end
        end
        true
      end
    
      def selection_bucket_key
        'trifle_all'
      end    
    
      def new_resource(params={})
        super(params).tap do |res|
          res.set_ark_naan(@parent.local_ark_naan) if @parent && !params[:ark_naan]
        end
      end

      def resource_params
        super.tap do |ret|
          if params[:action].to_sym == :create
            ark_naan = params[self.class.model_name.param_key.to_sym].try(:[],:ark_naan)
            ret.merge!(ark_naan: ark_naan) if ark_naan.present?
          end
        end
      end
          
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
    
      def preload_show
        super
        @resource.ancestors_from_solr!
      end
    
  end
end

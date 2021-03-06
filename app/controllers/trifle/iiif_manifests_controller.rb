module Trifle
  class IIIFManifestsController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase
    include DurhamRails::SelectableResourceBehaviour
    include DurhamRails::ReceiveMovesBehaviour
    include Trifle::ImageDepositBehaviour
    include Trifle::ServeIIIFBehaviour
    include Trifle::RefreshFromSourceBehaviour
    include Trifle::RepairWithOublietteBehaviour
    include Trifle::PublishResourceBehaviour
    include Trifle::LinkMillenniumBehaviour
    include Trifle::UpdateRangesBehaviour
    include Trifle::MemberReordering
    include Trifle::AllowCorsBehaviour # Keep this last

    helper 'trifle/application'

    before_action :set_sequence_iiif_resource, only: [:show_sequence_iiif]

    def self.presenter_terms
      super + [:digitisation_note, :identifier, :image_container_location, :date_published, :author, :description, :source_record, :licence, :attribution, :other_metadata, :dirty_state]
    end

    def self.form_terms
      super - [:dirty_state] + [:job_tag]
    end

    def set_parent
      @parent = IIIFCollection.find(params[:iiif_collection_id])      
    end
    
    def index
      if params['format'] == 'json' && params['mirador'] == 'true'
        resources = Trifle::IIIFManifest.all.from_solr!
        render json: (resources.map do |res|
          {manifestUri: trifle.iiif_manifest_iiif_url(res), location: Trifle.mirador_location }
        end)
      else
        super
      end  
    end
    
    def update
      if params[:iiif_manifest][:canvas_order].present?
        raise 'Invalid canvas list' unless reorder_members(params[:iiif_manifest][:canvas_order], Trifle::IIIFImage)
      end
      super
    end    
    
    def show_sequence_iiif
      raise 'Sequence name not given' unless params[:sequence_name]
      seq = @resource.iiif_sequences.find do |seq| seq.label==params[:sequence_name] end
      raise 'Invalid sequence' unless seq
      render json: seq.to_json(pretty: true)
    end    
    
    def authenticate_user!(opts={})
      return true if params[:action].to_sym == :index && params['format'] == 'json' && params['mirador'] == 'true'
      return super
    end
    def authorize_resource!
      return true if params[:action].to_sym == :index && params['format'] == 'json' && params['mirador'] == 'true'
      return true if params[:action].to_sym == :show_sequence_iiif
      return super
    end
    
    def index_resources
      return super if @parent || !params['in_source'].present?
      
      from = self.class.model_class.find_from_source(params["in_source"],params.fetch('in_source_prefix','true')=='true')
      if use_paging? && params['per_page'] != 'all'
        per_page = [[params.fetch('per_page', 20).to_i, 100].min, 5].max
        page = [params.fetch('page', 1).to_i, 1].max
        self.class.resources_for_page(page: page, per_page: per_page, from: from)
      else
        from
      end
    end
    
    def move_selection_into
      # This hook will only work if bucket is emptied on successful move.
      raise 'Assert error, empty_bucket_after_move? must be true' unless empty_bucket_after_move?
      
      changed = {}
      changed[@resource.id] = @resource
      
      selection_bucket.from_fedora!.each do |res|
        manifest = res.manifest
        changed[manifest.id] ||= manifest
      end
      
      super
      
      changed.values.each do |res|
        job = Trifle::PublishJob.new(resource: res)
        job.validate_job!
        job.queue_job
      end
    end
    
    protected

    def validate_move
      return false unless super
      selection_bucket.each do |res|
        unless res.is_a?(Trifle::IIIFImage)
          error_message = "Can only move images into a manifest"
          respond_to do |format|
            format.html { flash[:error] = error_message ; redirect_to @resource }
            format.json { render json: { status: 'error', message: error_message } }
          end          
          return false
        end
      end
      true
    end  

    def new_resource(params={})
      super(params).tap do |res|
        res.set_ark_naan(@parent.local_ark_naan) if @parent && !params[:ark_naan]
      end
    end
    
    def selection_bucket_key
      'trifle_all'
    end    
    
    def resource_params
      super.tap do |ret|
        if params[:action].to_sym == :create
          ark_naan = params[self.class.model_name.param_key.to_sym].try(:[],:ark_naan)
          ret.merge!(ark_naan: ark_naan) if ark_naan.present?
        end
      end
    end
        
    private 
      def set_cors_headers?
        return true if params[:action].to_sym == :index && params['format'] == 'json' && params['mirador'] == 'true'
        return super
      end
      
      def set_sequence_iiif_resource
        set_resource
      end
      
      def preload_show
        super
        @resource.ancestors_from_solr!
      end
    
  end
end

module Trifle
  class PublishJob
    include DurhamRails::Jobs::JobBase
    include DurhamRails::Jobs::WithResource
#    include DurhamRails::Jobs::WithUser
    include Trifle::TrifleJob
    
    attr_accessor :remove_id, :remove_type, :recursive
    
    def initialize(params={})
      super(params)
      
      case params[:remove]
      when nil
        self.remove_id = params[:remove_id]
        self.remove_type = params[:remove_type]
      when Trifle::IIIFManifest
        self.remove_type = 'manifest'
        self.remove_id = params[:remove].local_ark
        raise 'Remove object doesn\'t have a local_ark' unless remove_id.present?
      when Trifle::IIIFCollection
        self.remove_type = 'collection'
        self.remove_id = params[:remove].id
        raise 'Remove object doesn\'t have an id' unless remove_id.present?
      else
        raise "Unknown remove object type #{params[:remove].class}"
      end
      
      self.recursive = params.fetch(:recursive, false)
    end
    
    def queue_job
      existing_job = resource.queued_jobs.find do |_job| 
        next false unless _job.job_type == self.class.to_s
        job = Marshal.load(Base64.decode64(_job.job_data))
        job.remove_type == self.remove_type && job.remove_id == self.remove_id && job.recursive == self.recursive
      end
      if existing_job.present?
        # Don't queue another publish job if one is already queued. This will
        # still queue a new one if there's one running already.
        return true
      end
      super
    end
    
    def dump_attributes
      super + [:remove_id, :remove_type, :recursive]
    end        
    
    def validate_job!
      super
      raise "remove_id can't be present when recursively publishing" if remove_id.present? && recursive
      raise "Invalid resource type #{resource.class}" unless resource.is_a?(Trifle::IIIFManifest) || resource.is_a?(Trifle::IIIFCollection)
    end
        
    def run_job
      if recursive
        log.log_filter = Proc.new do |m|
          !(m.level == :info && m.message.start_with?("Sending file"))
        end
        
        iiif_actor = Trifle::RecursivePublishIIIFActor.new(resource)
        iiif_actor.instance_variable_set(:@log, log)
        iiif_actor.publish_recursive
      else
        iiif_actor = Trifle::PublishIIIFActor.new(resource)
        iiif_actor.instance_variable_set(:@log,log)
        iiif_actor.upload_package
        if remove_id.present?
          iiif_actor.remove_remote_package(remove_id, remove_type)
        end
      end
    end
    
  end
end
module Trifle
  class StatifyJob
    include DurhamRails::Jobs::JobBase
    include DurhamRails::Jobs::WithResource
#    include DurhamRails::Jobs::WithUser
    include Trifle::TrifleJob
    
    attr_accessor :remove_id, :remove_type
    
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
    end
    
    def dump_attributes
      super + [:remove_id, :remove_type]
    end        
    
    def validate_job!
      super
      raise "Invalid resource type #{resource.class}" unless resource.is_a?(Trifle::IIIFManifest) || resource.is_a?(Trifle::IIIFCollection)
    end
        
    def run_job
      iiif_actor = Trifle::StaticIIIFActor.new(resource)
      iiif_actor.instance_variable_set(:@log,log)
      iiif_actor.upload_package
      if remove_id.present?
        iiif_actor.remove_remote_package(remove_id, remove_type)
      end
    end
    
  end
end
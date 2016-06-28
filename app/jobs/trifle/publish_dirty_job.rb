module Trifle
  class PublishDirtyJob
    include DurhamRails::Jobs::JobBase
    include Trifle::TrifleJob
    include DurhamRails::Jobs::WithJobContainer

    def default_job_container_category
      :trifle
    end
    
    def run_job
      Trifle::IIIFManifest.all_dirty.each do |manifest|
        iiif_actor = Trifle::PublishIIIFActor.new(manifest)
        iiif_actor.instance_variable_set(:@log,log)
        iiif_actor.upload_package
      end
    end

  end
end
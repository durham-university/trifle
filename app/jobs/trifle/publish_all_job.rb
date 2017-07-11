module Trifle
  class PublishAllJob
    include DurhamRails::Jobs::JobBase
    include Trifle::TrifleJob
    include DurhamRails::Jobs::WithJobContainer

    def default_job_container_category
      :trifle
    end
    
    def run_job
      @error_count = 0
      Trifle::IIIFManifest.all.each do |m|
        break if @error_count > 10
        publish_resource(m)
      end
      Trifle::IIIFCollection.all.each do |c|
        break if @error_count > 10
        publish_resource(c)
      end
      # publish one root collection again to make it publish the collection index
      c = Trifle::IIIFCollection.root_collections.first
      publish_resource(c, false) if c.present?
    end
    
    protected
      
    def publish_resource(resource, skip_parent=true)
      iiif_actor = Trifle::PublishIIIFActor.new(resource, nil, skip_parent: skip_parent)
      iiif_actor.instance_variable_set(:@log,log)
      iiif_actor.upload_package.tap do |success|
        @error_count += 1 unless success
      end
    end
  end
end

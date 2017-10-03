module Trifle
  class PublishAllJob
    include DurhamRails::Jobs::JobBase
    include Trifle::TrifleJob
    include DurhamRails::Jobs::WithJobContainer

    def default_job_container_category
      :trifle
    end
    
    def run_job
      # Publishing resources recursively rather than in arbitrary order is better
      # for keeping relevant parent/child resources in memory rather than having
      # to resolve them separately for each resource.
            
      log.log_filter = Proc.new do |m|
        !(m.level == :info && m.message.start_with?("Sending file"))
      end
      
      actor = Trifle::RecursivePublishIIIFActor.new
      actor.instance_variable_set(:@log,log)
      
      first = true
      Trifle::IIIFCollection.root_collections.from_solr!.each do |c|
        if first
          first = false
          # this publishes root index
          actor.publish_single_resource(c, false)          
        end
        actor.publish_recursive(c)
      end
      nil
    end
    
  end
end

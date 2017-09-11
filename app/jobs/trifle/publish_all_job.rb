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
      @published_index = {}
      @max_errors = 10
      
      Trifle::IIIFCollection.root_collections.from_solr!.each do |c|
        break if @error_count > @max_errors
        
        if @published_index.empty?
          # Publish one root collection with parent included. This publishes
          # the root level index.
          publish_resource(c)
        end
        
        publish_resource_recursive(c)        
      end
      
    end
    
    protected
    
    # Publishing resources recursively rather than in arbitrary order is better
    # for keeping relevant parent/child resources in memory rather than having
    # to resolve them separately for each resource.
    def publish_resource_recursive(resource)
      return if @error_count > @max_errors
      return if @published_index.key?(resource.id)
      @published_index[resource.id] = true
      resource.ordered_members.from_solr!
      
      publish_resource(resource, true)
      
      if resource.is_a?(Trifle::IIIFCollection)
        resource.ordered_members.to_a.each do |m|
          break if @error_count > @max_errors
          publish_resource_recursive(m)
        end
      end
      
      # clear memory
      if resource.is_a?(DurhamRails::FastContainer)
        resource.instance_variable_set(:@ordered_items,nil)
        resource.instance_variable_set(:@ordered_item_ids,nil)
        resource.ordered_items_serial.instance_variable_set(:@content,nil)      
      else
        resource.ordered_members.instance_variable_set(:@association, nil)
      end
    end
      
    def publish_resource(resource, skip_parent=true)
      iiif_actor = Trifle::PublishIIIFActor.new(resource, nil, skip_parent: skip_parent)
      iiif_actor.instance_variable_set(:@log,log)
      iiif_actor.upload_package.tap do |success|
        @error_count += 1 unless success
      end
    end
  end
end

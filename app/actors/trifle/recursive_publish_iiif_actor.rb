module Trifle
  class RecursivePublishIIIFActor < Trifle::BaseActor

    def initialize(model_object=nil, user=nil, attributes={})
      super(model_object, user, attributes)
      @error_count = 0
      @max_errors = 10
      @published_index = {}
    end

    def publish_recursive(resource=nil)
      resource ||= @model_object
      
      return if @error_count > @max_errors
      return if @published_index.key?(resource.id)
      @published_index[resource.id] = true
      resource.ordered_members.from_solr!

      log!("Recursively publishing #{resource.title} (#{resource.id})")
      
      publish_single_resource(resource, true)
      
      if resource.is_a?(Trifle::IIIFCollection)
        resource.ordered_members.to_a.each do |m|
          break if @error_count > @max_errors
          publish_recursive(m)
        end
      end
      
      log!(:debug,"Done publishing #{resource.title} (#{resource.id})")
      
      # clear memory
      if resource.is_a?(DurhamRails::FastContainer)
        resource.instance_variable_set(:@ordered_items,nil)
        resource.instance_variable_set(:@ordered_item_ids,nil)
        resource.ordered_items_serial.instance_variable_set(:@content,nil)      
      else
        resource.ordered_members.instance_variable_set(:@association, nil)
      end
      @error_count
    end
    
    def publish_single_resource(resource, skip_parent=true)
      publish_actor = Trifle::PublishIIIFActor.new(resource, nil, skip_parent: skip_parent)
      publish_actor.instance_variable_set(:@log,log)
      publish_actor.upload_package.tap do |success|
        @error_count += 1 unless success
      end
    end    

  end
end
module Trifle
  module PublishResourceBehaviour
    extend ActiveSupport::Concern
    
    included do
      before_action :validate_publish_job!, only: [:update] # don't try to validate before create, the resource won't exist at that point
      before_action :validate_remove_publish_job!, only: [:destroy]
      before_action :set_publish_resource, only: [:publish]
      around_action :remove_published_hook, only: [:destroy]
    end
    
    def publish
      # queue_publish_job authorizes! action
      success = queue_publish_job
      
      respond_to do |format|
        if success
          format.html { redirect_to @resource, notice: "Publish job was successfully queued." }
          format.json { render json: { resource: @resource.as_json, status: 'ok'} }
        else
          format.html { 
            flash[:error] = "Unable to queue publish iiif job."
            redirect_to @resource
          }
          format.json { render json: { resource: @resource.as_json, status: 'error', message: "Unable to queue publish job."} }
        end
      end      
    end
    
    protected
    
    def create_reply(success)
      queue_publish_job if success && publish?
      super(success) 
    end
    
    def update_reply(success)
      queue_publish_job if success && publish?
      super(success)
    end    
        
    private 
    
      def publish?
        params[:publish]=='true'
      end
    
      def set_publish_resource
        set_resource
      end
    
      def publish_job
        @publish_job ||= Trifle::PublishJob.new(resource: @resource)
      end
      
      def remove_published_hook
        parents = @resource.parents.to_a
        yield
        if @resource.destroyed?
          if parents.any?
            parents.each_with_index do |parent,index|
              params = { resource: parent }
              params.merge!({remove: @resource}) if index==0
              Trifle::PublishJob.new( params ).queue_job
            end
          else
            # Just pick any top-level collection where we can attach a job.
            # This should be a rare occurrence. Should also prevent removing
            # last collection. Using a top-level collection for this will also
            # update the pseudo index collection.
            c = Trifle::IIIFCollection.root_collections.first
            Trifle::PublishJob.new( {resource: c, remove: @resource} ).queue_job 
          end
        end
      end
    
      def validate_publish_job!
        return unless publish?
        publish_job.validate_job!
      end
      
      def validate_remove_publish_job!
        if @resource.parents.any?
          @resource.parents.each do |parent|
            raise 'One of the object parents already has a background job. Cannot remove object right now.' if parent.background_job_running?
          end
        else
          c = Trifle::IIIFCollection.first
          raise 'Cannot remove object with no remaining collections.' unless c
          raise 'First collection already has a background job. Cannot remove object right now.' if c.background_job_running?
        end
      end
    
      def queue_publish_job
        authorize!(:publish, @resource)
        begin
          publish_job.queue_job
          true
        rescue StandardError => e
          false
        end
      end
  end
end
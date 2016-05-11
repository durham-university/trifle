module Trifle
  module StatifyResourceBehaviour
    extend ActiveSupport::Concern
    
    included do
      before_action :validate_statify_job!, only: [:update] # don't try to validate before create, the resource won't exist at that point
      before_action :validate_remove_statify_job!, only: [:destroy]
      around_action :remove_static_hook, only: [:destroy]
    end

    def create_reply(success)
      queue_statify_job if success
      super(success)
    end
    
    def update_reply(success)
      queue_statify_job if success
      super(success)
    end
    
    private 
      def statify_job
        @statify_job ||= Trifle::StatifyJob.new(resource: @resource)
      end
      
      def remove_static_hook
        parents = @resource.parents.to_a
        yield
        if @resource.destroyed?
          if parents.any?
            parents.each_with_index do |parent,index|
              params = { resource: parent }
              params.merge!({remove: @resource}) if index==0
              Trifle::StatifyJob.new( params ).queue_job
            end
          else
            # Just pick any collection where we can attach a job.
            # This should be a rare occurrence. Should also prevent removing
            # last collection.
            c = Trifle::IIIFCollection.first
            Trifle::StatifyJob.new( {resource: c, remove: @resource} ).queue_job            
          end
        end
      end
    
      def validate_statify_job!
        statify_job.validate_job!
      end
      
      def validate_remove_statify_job!
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
    
      def queue_statify_job
        begin
          statify_job.queue_job
        rescue StandardError => e
          flash[:error] = "Unable to queue static iiif job. #{error_message}" if error_message
        end
      end
  end
end
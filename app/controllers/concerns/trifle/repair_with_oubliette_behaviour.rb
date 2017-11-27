module Trifle
  module RepairWithOublietteBehaviour
    extend ActiveSupport::Concern

    included do
      before_action :set_repair_with_oubliette_resource, only: [:repair_with_oubliette]
    end
    
    def repair_with_oubliette
      success = queue_repair_job
      
      respond_to do |format|
        if success
          format.html { redirect_to @resource, notice: "Repair job was successfully queued." }
          format.json { render json: { resource: @resource.as_json, status: 'ok'} }
        else
          format.html { 
            flash[:error] = "Unable to queue repair job."
            redirect_to @resource
          }
          format.json { render json: { resource: @resource.as_json, status: 'error', message: "Unable to queue repair job."} }
        end
      end      
    end
    
    private

      def repair_job
        @repair_job ||= Trifle::RepairManifestJob.new(resource: @resource)
      end

      def queue_repair_job
        authorize!(:repair_with_oubliette, @resource)
        begin
          repair_job.queue_job
          true
        rescue StandardError => e
          false
        end
      end      
  
      def set_repair_with_oubliette_resource
        set_resource
      end
    
  end
end

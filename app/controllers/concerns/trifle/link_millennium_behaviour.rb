module Trifle
  module LinkMillenniumBehaviour
    extend ActiveSupport::Concern

    included do
      before_action :set_link_millennium_resource, only: [:link_millennium]
      before_action :validate_link_millennium_job!, only: [:link_millennium]
    end
    
    def link_millennium
      # queue_link_millennium_job authorizes! action
      success = queue_link_millennium_job
      
      respond_to do |format|
        if success
          format.html { redirect_to @resource, notice: "Millennium link job was successfully queued." }
          format.json { render json: { resource: @resource.as_json, status: 'ok'} }
        else
          format.html { 
            flash[:error] = "Unable to queue Millennium link job."
            redirect_to @resource
          }
          format.json { render json: { resource: @resource.as_json, status: 'error', message: "Unable to queue Millennium link job."} }
        end
      end      
    end
    
    protected
    
    def set_link_millennium_resource
      set_resource
    end
    
    def validate_link_millennium_job!
      link_millennium_job.validate_job!
    end
        
    def link_millennium_job
      @link_millennium_job ||= Trifle::MillenniumLinkJob.new(resource: @resource)
    end
        
    def queue_link_millennium_job
      authorize!(:link_millennium, @resource)
      begin
        link_millennium_job.queue_job
        true
      rescue StandardError => e
        false
      end
    end
    
  end
end

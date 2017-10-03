module Trifle
  class BackgroundJobContainersController < Trifle::ApplicationController
    include DurhamRails::BackgroundJobContainersControllerBehaviour
    
    before_action :authenticate_publish_all_job_user!, only: [:start_publish_all_job]
    
    def self.form_terms
      super - [:job_category]
    end
    
    def start_publish_all_job
      success = Trifle::PublishAllJob.new.queue_job
      
      respond_to do |format|
        format.html { redirect_to DurhamRails::BackgroundJobContainer, notice: "Publish all job started" }
        format.json { render json: {status: success } }
      end
    end    
    
    protected
    
      def job_container_category
        :trifle
      end
      
      def authenticate_publish_all_job_user!
        authenticate_user!
      end      
    
  end
end
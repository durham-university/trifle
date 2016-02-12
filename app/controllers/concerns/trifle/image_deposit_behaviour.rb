module Trifle
  module ImageDepositBehaviour
    extend ActiveSupport::Concern

    included do
      before_action :set_deposit_resource, only: [:deposit_images]
    end
    
    def deposit_images
      authorize!(:deposit, @resource)
      job = Trifle::DepositJob.new(resource: @resource, deposit_items: deposit_items)
      
      success = false
      error_message = nil
      begin
        success = job.queue_job
      rescue StandardError => e
        error_message = e.to_s
      end
      
      respond_to do |format|
        if success
          format.html { redirect_to @resource, notice: "Deposit job was successfully queued." }
          format.json { render json: { resource: @resource.as_json, status: 'ok'} }
        else
          format.html { 
            flash[:error] = "Unable to queue deposit job. #{error_message}" 
            redirect_to @resource
          }
          format.json { render json: { resource: @resource.as_json, status: 'error', message: "Unable to queue deposit job. #{error_message}"} }
        end
      end      
    end
    
    def create_and_deposit_images
      authorize!(:create_and_deposit, Trifle::IIIFManifest)
      
      # params['iiif_manifest'] must have something in it, otherwise resource_params
      # won't work. And we want to assign an automatic title anyway.
      params['iiif_manifest'] ||= {}
      params['iiif_manifest']['title'] ||= "New manifest #{DateTime.now.strftime('%F %R')}"
      set_resource( new_resource(resource_params) )
      
      @resource.default_container_location!
      
      unless @resource.save
        respond_to do |format|
          format.html { 
            flash[:error] = "Unable to create manifest." 
            redirect_to root_url
          }
          format.json { render json: { status: 'error', message: 'unable to create manifest'} }
        end      
        return
      end
      
      deposit_images
    end
    
    private
      def deposit_items
        params['deposit_items'].select do |item|
          item.is_a?(String) && (item.start_with?('http://') || item.start_with?('https://'))
        end
      end
      
      def set_deposit_resource
        set_resource
      end
            
  end
end
module Trifle
  module ImageDepositBehaviour
    extend ActiveSupport::Concern

    included do
      before_action :set_deposit_resource, only: [:deposit_images]
      before_action :set_deposit_parent, only: [:create_and_deposit_images]
      before_action :authorize_deposit_to_parent_resource!, only: [:create_and_deposit_images]
    end
    
    def deposit_images
      job = Trifle::DepositJob.new(resource: @resource, deposit_items: deposit_item_params)
      
      success = false
      error_message = nil
      begin
        success = job.queue_job
      rescue StandardError => e
        error_message = e.to_s
      end
      
      deposit_reply(success, error_message)
    end
    
    def create_and_deposit_images
      duplicate = Trifle::IIIFManifest.find_job_duplicate(params.try(:[],'iiif_manifest').try(:[],'job_tag'))
      if duplicate.present?
        @resource = duplicate
        return deposit_reply(true, nil)
      end
      
      # NOTE: This is usually called through Trifle::API::IIIFManifest.deposit_new.
      #       The local version of that does not come to this controller code but instead
      #       duplicates most of this.
      
      # params['iiif_manifest'] must have something in it, otherwise resource_params
      # won't work. And we want to assign an automatic title anyway.
      params['iiif_manifest'] ||= {}
      params['iiif_manifest']['title'] ||= "New manifest #{DateTime.now.strftime('%F %R')}"
      set_resource( new_resource(resource_params) )
      
      @resource.default_container_location!
      
      # @resource.refresh_from_source if @resource.source_record.present?
      
      saved = false
      if @resource.valid?
        if @parent
          @parent.ordered_members << @resource
          saved = @parent.save && @resource.save
        else
          saved = @resource.save
        end
      end
            
      unless saved
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
      def deposit_reply(success, error_message=nil)
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
    
      def validate_ingestion_path(path)
        ingestion_paths = Array(Trifle.config['ingestion_path'])
        raise 'Ingestion from disk not supported' unless ingestion_paths.any?
        ingestion_paths.each do |ingestion_path|
          ingestion_path += File::SEPARATOR unless ingestion_path.ends_with? File::SEPARATOR
          abs_path = File.absolute_path(path)
          next unless abs_path.start_with?(ingestion_path) && abs_path.length > ingestion_path.length
          raise "Ingestion file #{abs_path} is a directory" if File.directory?(abs_path)
          return true
        end
        
        raise "Not allowed to ingest from #{path}"
      end
    
      def deposit_item_params
        parsed_items = if params['deposit_items'].respond_to?(:read)
          JSON.parse(params['deposit_items'].read).map do |h|
            next nil unless h.is_a?(Hash)
            h.with_indifferent_access
          end .compact
        else
          params['deposit_items']
        end
        
        parsed_items.select do |item|
          next false unless item.is_a?(Hash)
          next false unless item[:source_path].present?
          
          if item[:temp_file].present?
            # validation raises exceptions if any issues
            next false unless validate_ingestion_path(item[:temp_file])
          end
          
          (item[:source_path].start_with?('oubliette:') || item[:source_path].start_with?('http://') || item[:source_path].start_with?('https://'))
        end
      end
      
      def set_deposit_resource
        set_resource
      end
      
      def set_deposit_parent
        set_parent
      end
      
      def authorize_deposit_to_parent_resource!
        authorize!(:deposit_into, @parent) if @parent
      end      
            
  end
end
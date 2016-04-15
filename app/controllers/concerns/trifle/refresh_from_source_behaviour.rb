module Trifle
  module RefreshFromSourceBehaviour
    extend ActiveSupport::Concern

    included do
      before_action :set_refresh_from_source_resource, only: [:refresh_from_source]
    end
    
    def refresh_from_source
      authorize!(:refresh_from_source, @resource)      
      
      respond_to do |format|
        if @resource.refresh_from_source && @resource.save
          format.html { redirect_to @resource, notice: "#{self.class.model_name.humanize} was successfully refreshed from source." }
          format.json { render json: {status: :ok, resource: @resource.as_json } }
        else
          format.html { 
            flash[:error] = "There was an error updating the resource from source" 
            redirect_to @resource
          }
          format.json { render json: { error: "There was an error updating the resource from source"}, status: :unprocessable_entity }
        end
      end
    end
    
    private
      def set_refresh_from_source_resource
        set_resource
      end
    
  end
end

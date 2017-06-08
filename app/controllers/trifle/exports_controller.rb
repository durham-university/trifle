module Trifle
  class ExportsController < Trifle::ApplicationController
    before_action :authenticate_user!, only: [:show, :export_images]
    before_action :authorize_resource!
    
    def show
    end
    
    def export_images
      oubliette_params = export_params
      
      export_ids = parse_export_ids(oubliette_params[:export_ids])
      images = Trifle::IIIFImage.all.from_solr!.find_some(export_ids)
      nil_ind = images.index(nil)
      raise "Couldn't find image #{oubliette_params[:export_ids][nil_ind]}" unless nil_ind.nil?
      
      authorize_export_images(images)
      oubliette_params[:export_ids] = get_oubliette_export_ids(images)
      
      job_id = Oubliette::API::PreservedFile.export(oubliette_params)
      success = job_id.present?
      
      respond_to do |format|
        format.html { 
          if success
            redirect_to exports_url, notice: "Export job sent to Oubliette. <a href=\"#{oubliette_job_link(job_id)}\">Open job in Oubliette</a>"
          else
            flash[:error] = "Error starting export job."
            redirect_to exports_url
          end
        }
        format.json { render json: {status: success, job_id: success ? job_id : nil} }
      end      
    end
    
    protected
    
      def authorize_resource!
        authorize!(params[:action].to_sym, :export)
      end
    
      def authorize_export_images(images)
        images.each do |image|
          authorize!(:export, image)
        end
      end
      
      def parse_export_ids(id_list)
        re = /.*\?.*canvas=([^&]+)(&|$)/
        id_list.map do |id|
          m = id.match(re)
          if m
            m[1]
          else
            ind = id.rindex('/')
            ind.nil? ? id : id[(ind+1)..-1]  
          end
        end
      end
      
      def get_oubliette_export_ids(images)
        images.map do |img|
          raise "Image #{img.id} is not from Oubliette" unless img.image_source.start_with?('oubliette:')
          img.image_source[('oubliette:'.length)..-1]
        end
      end
      
      def export_params
        export_ids_raw = Array.wrap(params[:export_ids])
        export_ids = []
        export_ids_raw.each do |raw_id|
          next unless raw_id.present?
          raw_id.split(/[\s,]+/).each do |id|
            export_ids << id
          end
        end
        raise 'No export_ids given' unless export_ids.present?
        raise 'Too many export ids given' if export_ids.length > 500

        {
          export_ids: export_ids,
          export_method: :store,
          export_note: params[:export_note],
#          export_destination: params[:export_destination]
        }
      end
      
      def oubliette_job_link(job_id)
        "#{Oubliette::API.config['base_url']}/background_jobs/#{job_id}"
      end
    
  end
end
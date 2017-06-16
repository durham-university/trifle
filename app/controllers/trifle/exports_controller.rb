module Trifle
  class ExportsController < Trifle::ApplicationController
    before_action :authenticate_user!, only: [:show, :export_images]
    before_action :authorize_resource!
    
    def show
    end
    
    def export_images
      oubliette_params = export_params
      
      images = get_export_images(oubliette_params[:export_ids])
      
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
      
      def parse_export_id(id)
        m = id.match(/.*\?.*canvas=([^&]+)(&|$)/)
        if m
          m[1]
        else
          ind = id.rindex('/')
          ind.nil? ? id : id[(ind+1)..-1]  
        end
      end
      
      def get_export_images(image_ids)
        # note, image_ids may contain image ranges
        image_index = {}
        flattened_ids = image_ids.flatten.uniq
        Trifle::IIIFImage.all.from_solr!.find_some(flattened_ids).each_with_index do |image,i|
          raise "Couldn't find image #{flattened_ids[i]}" if image.nil?
          image_index[image.id] = image
        end
        image_ids.map do |id|
          if id.is_a?(String)
            image_index[id]
          else
            img1 = image_index[id[0]]
            img2 = image_index[id[1]]
            raise 'Images in image range don\'t share the same manifest' unless img1.manifest.id == img2.manifest.id
            manifest_images = img1.manifest.ordered_members.from_solr!.to_a
            ind1 = manifest_images.index do |img| img.id == img1.id end
            ind2 = manifest_images.index do |img| img.id == img2.id end
            ind1, ind2 = ind2, ind1 if ind1 > ind2
            manifest_images[ind1..ind2]
          end
        end .flatten
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
            id = parse_export_id(id) unless id == '-'
            if export_ids.last == '-'
              # handle id ranges like "id1 - id2"
              export_ids.pop
              raise 'Invalid id range' if export_ids.empty? || !export_ids.last.is_a?(String)
              export_ids << [export_ids.pop, id]
            else
              export_ids << id
            end
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
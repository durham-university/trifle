module Trifle
  class ImageDepositActor < Trifle::BaseActor
    include DurhamRails::Actors::ShellRunner
    include DurhamRails::Actors::SFTPUploader
    include DurhamRails::Actors::FileCopier
    include DurhamRails::Actors::FitsRunner

    def initialize(model_object, user=nil, attributes={})
      @source_record_cache = {}
      super(model_object, user, attributes)
    end

    def convert_image(source_path, dest_path, conversion_profile='default')
      log!(:info,"Converting image #{source_path} to #{dest_path} (colour space #{@image_analysis.try(:[],:colour_space)})")
      cs = (['BlackIsZero','WhiteIsZero'].include?(@image_analysis.try(:[],:colour_space)) ? 'BW' : 'RGB')
      stdout, stderr, exit_status = shell_exec('',*(convert_command+[source_path,dest_path,cs,conversion_profile]))
      if exit_status!=0
        log!(:error,"Error converting image. (#{exit_status})")
        log!(:error, stderr) if stderr.present?
        log!(:error, stdout) if stdout.present?
        return false
      else
        log!(:debug,stdout) if stdout.present?
      end
      return true
    end

    def create_image_object(metadata={})
      Trifle::IIIFImage.new.tap do |image|
        image.set_ark_naan(metadata['ark_naan'])
        image.image_location = @logical_path
        image.image_source = metadata['source_path'] if metadata['source_path'].present?
        image.title = metadata['title'] if metadata['title'].present?
        image.source_record = metadata['source_record'] if metadata['source_record'].present?
        image.width = "#{@image_analysis[:width]}"
        image.height = "#{@image_analysis[:height]}"
        if image.source_record.present? && !metadata['description'].present?
          # Update_from_source currently only sets description. No need to do
          # this if description is overwritten with metadata anyway.
          image.refresh_from_source(@source_record_cache)
        end
        image.description = metadata['description'] if metadata['description'].present?
      end
    end

    def analyse_image(source_path)
      log!(:info, "Structural analysis of image")
      
      (fits_xml, error_out, exit_code) = run_fits(source_path)
      unless exit_code == 0
        log!(:error, "Unable to run Fits. #{error_out}")
        return false
      end
      
      width = fits_xml.xpath('/xmlns:fits/xmlns:metadata/xmlns:image/xmlns:imageWidth[@toolname="Jhove"]/text()').first.to_s.to_i
      height = fits_xml.xpath('/xmlns:fits/xmlns:metadata/xmlns:image/xmlns:imageHeight[@toolname="Jhove"]/text()').first.to_s.to_i
      colour_space = fits_xml.xpath('/xmlns:fits/xmlns:metadata/xmlns:image/xmlns:colorSpace[@toolname="Jhove"]/text()').first.to_s

      unless width.present? && height.present?
        log!(:error, "Unable determine image size.")
        log!(:error, error_out) if error_out.present?
        return false
      end
      
      @image_analysis = {width: width, height: height, colour_space: colour_space}

      return true
    end

    def add_to_image_container(metadata={})
      log!(:info, "Adding to image container #{@model_object.id}")
      metadata = metadata.reverse_merge(ark_naan: @model_object.local_ark_naan) if @model_object.local_ark_naan
      image_obj = create_image_object(metadata)
      return false unless image_obj
      ret_val = @model_object.add_deposited_image(image_obj)
      log!(:error, "Unable to add image to container") unless ret_val
      return ret_val
    end
    
    # Deposit from Net::HTTPResponse
    def deposit_from_response(resp, metadata)
      temp_file = nil
      begin
        extension = ''
        if resp.content_type.present?
          mime = MIME::Types[resp.content_type].first
          extension = ".#{mime.extensions.first}" if mime.present?
        end
        temp_file = Tempfile.open(['',extension],temp_dir, binmode: true)
        log!(:info,"...saving to #{temp_file.path}")
        resp.read_body do |chunk|
          temp_file.write(chunk)
        end
        temp_file.close
        return deposit_image(temp_file.path, metadata)        
      ensure
        temp_file.unlink if temp_file
      end
    end
    
    def deposit_from_oubliette(oubliette_url,metadata={})
      id = oubliette_url
      id = id[10..-1] if id.start_with?('oubliette:')
      metadata = metadata.merge({'source_path' => oubliette_url})

      log!(:info,"Downloading from Oubliette #{id}")
      ofile = Oubliette::API::PreservedFile.try_find(id)
      unless ofile
        log!(:error, "Couldn't find file in Oubliette")
        return false
      end
      status = false
      ofile.download do |resp|
        status = deposit_from_response(resp, metadata)
      end
      status
    end

    def deposit_from_url(source_url,metadata={})
      log!(:info,"Downloading #{source_url}")
      metadata = metadata.merge({'source_path' => source_url})
      status = false
      Net::HTTP.get_response(URI(source_url)) do |resp|
        status = deposit_from_response(resp, metadata)
      end
      status
    end
    
    def deposit_tempfile(source_path,metadata={})
      if metadata['temp_file'] && File.exists?(metadata['temp_file'])
        log!(:info,"Depositing from temp_file #{metadata['temp_file']}, original source #{source_path}")
        deposit_image(metadata['temp_file'],metadata.merge('source_path' => source_path).except('temp_file'))
      else
        false
      end
    end

    def deposit_image(source_path,metadata={})
      return true if deposit_tempfile(source_path,metadata)
      return deposit_from_oubliette(source_path,metadata) if source_path.start_with?('oubliette:')
      return deposit_from_url(source_path,metadata) if source_path.start_with?('http://') || source_path.start_with?('https://')

      file_base = file_path(metadata)
      log!(:info,"Depositing #{source_path}")
      unless container_dir
        log!(:error,"Couldn't resolve image container location")
        return false
      end
      @logical_path = "#{container_dir}/#{file_base}.#{image_format}"
      dest_path = File.join(image_base_path,container_dir,"#{file_base}.#{image_format}")
      if container_dir.include?('..')
        log!(:error,"Suspicious container_dir #{container_dir}")
        return false
      end
      
      connection_params = Trifle.config['image_server_config'].symbolize_keys.except(:root, :iiif_root, :images_root)
      
      convert_file = Tempfile.new(['trifle_convert',".#{image_format}"])
      begin
        convert_file.close
        convert_path = convert_file.path
        
        metadata = metadata.stringify_keys.reverse_merge({
          'source_path' => source_path,
          'conversion_profile' => 'default'
        })
        
        analyse_image(source_path) && convert_image(source_path, convert_path, metadata['conversion_profile']) &&
          send_or_copy_file(convert_path, dest_path, connection_params) && 
          add_to_image_container(metadata)
      ensure
        convert_file.unlink if convert_file
      end
    end
    
    def send_or_copy_file(source, dest_path, connection_params)
      if connection_params[:local_copy].to_s == 'true'
        return copy_file_local(source, dest_path, connection_params)
      else
        return send_file(source, dest_path, connection_params.except(:local_copy))
      end
    end
    
    def deposit_image_batch(image_data)
      log!(:info,"Depositing image batch")
      status = true
      index_offset = @model_object.ordered_members.to_a.count
      image_data.each_with_index do |hash,i|
        hash = {'source_path' => hash.to_s} unless hash.is_a? Hash
        hash = hash.stringify_keys
        hash['title'] ||= "#{index_offset+i+1}"
        status &= deposit_image(hash['source_path'],hash.except('source_path'))
      end
      status
    end

    private

      def file_path(metadata)
        metadata['basename'] || SecureRandom.hex
      end

      def container_dir
        @model_object.image_container_location
      end

      def image_base_path
        Trifle.config['image_server_config']['images_root']
      end

      def image_format
        Trifle.config['image_convert_format']
      end

      def convert_command
        Trifle.config['image_convert_command']
      end

      def temp_dir
        Trifle.config.fetch('image_convert_temp_dir',Dir.tmpdir)
      end

  end
end

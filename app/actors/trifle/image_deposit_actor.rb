module Trifle
  class ImageDepositActor < Trifle::BaseActor
    include DurhamRails::Actors::ShellRunner
    include DurhamRails::Actors::SFTPUploader
    include DurhamRails::Actors::FileCopier

    def initialize(model_object, user=nil, attributes={})
      super(model_object, user, attributes)
    end

    def convert_image(source_path,dest_path)
      log!(:info,"Converting image #{source_path} to #{dest_path}")
      stdout, stderr, exit_status = shell_exec('',*(convert_command+[source_path,dest_path]))
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
        image.width = "#{@image_analysis[:width]}"
        image.height = "#{@image_analysis[:height]}"
      end
    end

    def analyse_image(dest_path)
      log!(:info, "Structural analysis of image")

      stdout, stderr, exit_status = shell_exec('',*(image_size_command+[dest_path]))
      scan = stdout.scan(/(\d+)x(\d+)/)
      unless scan.present?
        log!(:error, "Unable determine image size. (#{exit_status})")
        log!(:error, stderr) if stderr.present?
        log!(:error, stdout) if stdout.present?
        return false
      end

      @image_analysis ||= {}
      @image_analysis.merge!( width: scan[0][0].to_i, height: scan[0][1].to_i )

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
      ofile.download do |resp|
        deposit_from_response(resp, metadata)
      end
    end

    def deposit_from_url(source_url,metadata={})
      log!(:info,"Downloading #{source_url}")
      metadata = metadata.merge({'source_path' => source_url})
      Net::HTTP.get_response(URI(source_url)) do |resp|
        deposit_from_response(resp, metadata)
      end
    end

    def deposit_image(source_path,metadata={})
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
        
        metadata = metadata.stringify_keys.reverse_merge({'source_path' => source_path})
        
        convert_image(source_path, convert_path) && analyse_image(convert_path) &&
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

      def image_size_command
        Trifle.config['image_size_command']
      end

      def temp_dir
        Trifle.config.fetch('image_convert_temp_dir',Dir.tmpdir)
      end

  end
end

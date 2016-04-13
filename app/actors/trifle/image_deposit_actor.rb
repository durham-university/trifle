module Trifle
  class ImageDepositActor < Trifle::BaseActor
    include DurhamRails::Actors::ShellRunner

    def initialize(model_object, user=nil, attributes={})
      @overwrite = attributes.fetch(:overwrite,false)
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
        image.image_location = @logical_path
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
      image_obj = create_image_object(metadata)
      return false unless image_obj
      ret_val = @model_object.add_deposited_image(image_obj)
      log!(:error, "Unable to add image to container") unless ret_val
      return ret_val
    end

    def deposit_url(source_url,metadata={})
      temp_file = nil
      begin
        log!(:info,"Downloading #{source_url}")
        Net::HTTP.get_response(URI(source_url)) do |resp|
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
        end
        temp_file.close
        return deposit_image(temp_file.path, metadata)
      ensure
        temp_file.unlink if temp_file
      end
    end

    def deposit_image(source_path,metadata={})
      return deposit_url(source_path,metadata) if source_path.start_with?('http://') || source_path.start_with?('https://')

      file_base = file_path(metadata)
      log!(:info,"Depositing #{source_path}")
      unless container_dir
        log!(:error,"Couldn't resolve image container location")
        return false
      end
      @logical_path = "#{container_dir}/#{file_base}.#{image_format}"
      dest_path = File.join(image_base_path,container_dir,"#{file_base}.#{image_format}")

      unless File.absolute_path(dest_path).start_with?("#{File.absolute_path(image_base_path)}#{File::SEPARATOR}")
        log!(:error, "Destination path is not under image_base_path")
        return false
      end

      if File.exists?(dest_path)
        if @overwrite
          log!(:info,"Overwriting destination file #{dest_path}")
        else
          log!(:error,"Destination file #{dest_path} already exists")
          return false
        end
      end
      FileUtils.mkpath(File.join(image_base_path,container_dir))

      convert_image(source_path, dest_path) && analyse_image(dest_path) &&
        add_to_image_container(metadata)
    end

    def deposit_image_batch(image_data)
      log!(:info,"Depositing image batch")
      status = true
      index_offset = @model_object.ordered_members.to_a.count
      image_data.each_with_index do |hash,i|
        hash = {source_path: hash.to_s} unless hash.is_a? Hash
        hash['title'] ||= "#{index_offset+i+1}"
        status &= deposit_image(hash[:source_path],hash.except(:source_path))
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
        Trifle.config['iipi_dir']
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

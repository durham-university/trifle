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
        image.title = metadata[:title] if metadata[:title].present?
        # TODO: add image width and height from analysis
        # TODO: add other metadata
      end
    end

    def analyse_image
      log!(:info, "Structural analysis of image")
      # TODO: Read image width and height and possibly other things
      return true
    end

    def add_to_image_container(metadata={})
      log!(:info, "Addin to image container")
      image_obj = create_image_object(metadata)
      return false unless image_obj
      ret_val = @model_object.add_deposited_image(image_obj)
      log!(:error, "Unable to add image to container") unless ret_val
      return ret_val
    end

    def deposit_image(source_path,metadata={})
      file_base = file_path(metadata)
      log!(:info,"Depositing #{file_base}")
      unless container_dir
        log!(:error,"Couldn't resolve image container location")
        return false
      end
      @logical_path = "#{container_dir}/#{file_base}.#{image_format}"
      dest_path = File.join(image_base_path,container_dir,"#{file_base}.#{image_format}")

      if File.exists?(dest_path)
        if @overwrite
          log!(:info,"Overwriting destination file #{dest_path}")
        else
          log!(:error,"Destination file #{dest_path} already exists")
          return false
        end
      end

      convert_image(source_path, dest_path) && analyse_image &&
        add_to_image_container(metadata)
    end

    def deposit_image_batch(image_data)
      log!(:info,"Depositing image batch")
      status = true
      image_data.each do |hash|
        status &= deposit_image(hash[:source_path],hash.except(:source_path))
      end
      status
    end

    private

      def file_path(metadata)
        metadata[:basename] || SecureRandom.hex
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

      def temp_dir
        Trifle.config.fetch('image_convert_temp_dir',Dir.tmpdir)
      end

  end
end

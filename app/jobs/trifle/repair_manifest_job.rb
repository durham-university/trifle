module Trifle
  class RepairManifestJob
    include DurhamRails::Jobs::JobBase
    include DurhamRails::Jobs::WithResource
    include Trifle::TrifleJob

    def run_job
      sources = resource.images.map do |img|
        img.image_source
      end .compact

      oubliette_ids = sources.map do |source|
        source.start_with?('oubliette:') ? source[('oubliette:'.length)..-1] : nil
      end .compact

      if oubliette_ids.length == 0
        log!(:error, "Manifest does not have any images from Oubliette, cannot resolve Oubliette batch");
        return
      end

      oubliette_image = Oubliette::API::PreservedFile.find(oubliette_ids.first)
      oubliette_batch = oubliette_image.parent

      unless oubliette_batch.present?
        log!(:error, "Couldn't find image batch in Oubliette")
        return
      end

      deposit_items = []
      oubliette_batch.files.each do |oubliette_file|
        next if oubliette_ids.include?(oubliette_file.id)
        log!(:info, "Found missing image #{oubliette_file.title} (#{oubliette_file.id})")
        deposit_items << {
          'source_path' => "oubliette:#{oubliette_file.id}", 
          'title' => oubliette_file.title
# There's no way to recover these from the data available
#          'description' => 
#          'source_record' => 
#          'identifier' => 
#          'conversion_profile' =>
        }
      end

      if deposit_items.empty?
        log!(:error, "No items to deposit")
        return
      end

      actor = Trifle::ImageDepositActor.new(resource)
      actor.instance_variable_set(:@log,log)
      if actor.deposit_image_batch(deposit_items)
        iiif_actor = Trifle::PublishIIIFActor.new(resource)
        iiif_actor.instance_variable_set(:@log,log)
        iiif_actor.upload_package
      end
      
    end
      
  end
end
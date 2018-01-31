module Trifle
  class LayersActor < Trifle::BaseActor

    # makes image a layer of model_object, which should be another image
    def make_image_a_layer(image, options={})
      make_images_layers([image], options)
    end

    def make_images_layers(images, options={})
      raise 'Model object must be an image' unless model_object.is_a?(Trifle::IIIFImage)    
      images.each do |image| 
        raise "Parameter is not a Trifle::IIIFImage" unless image.is_a?(Trifle::IIIFImage) 
        raise "Tried to convert containing object into a layer in itself" if image.id == model_object.id
        raise "Target image has layers" if image.layers.any?
      end
      images.each do |image|
        layer = Trifle::IIIFLayer.new(model_object,
          title: image.annotation_label || image.title,
          description: image.description,
          image_location: image.image_location,
          image_source: image.image_source,
          width: image.width,
          height: image.height,
          embed_xywh: "0,0,#{image.width},#{image.height}"
        )
        layer.assign_id!
        model_object.layers << layer
      end
      model_object.serialise_layers
      if model_object.save
        images.each do |image| image.destroy end unless options[:no_destroy]
        true
      else
        false
      end    
    end

    def make_layer_an_image
      layer = model_object
      image = layer.parent
      raise "Couldn't resolve parent image" unless image.is_a?(Trifle::IIIFImage)
      manifest = image.parent
      raise "Couldn't resolve parent manifest" unless manifest.is_a?(Trifle::IIIFManifest)
      image = Trifle::IIIFImage.create(
        title: layer.title,
        description: layer.description,
        image_location: layer.image_location,
        image_source: layer.image_source,
        width: layer.width,
        height: layer.height
      )
      return nil unless image.persisted?
      manifest.ordered_members << image
      if manifest.save
        layer.destroy
        image
      else
        nil
      end
    end

  end
end

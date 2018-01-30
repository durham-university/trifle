module Trifle
  class IIIFLayer
    include Trifle::ModelBase
    include DurhamRails::SerialisedObject
    
    attr_accessor :title, :image_location, :description, :image_source
    attr_accessor :width, :height, :embed_xywh
    
    def self.attribute_names
      super + ['title', 'description', 'image_location', 'image_source', 'width', 'height', 'embed_xywh']
    end

    def self.multiple?(field)
      field.to_sym == :identifier || super
    end

    def self.container_class
      Trifle::IIIFImage
    end

    def self.container_key
      'image'
    end

    def self.key_in_container
      'layers'
    end

    def manifest
      parent_image.manifest
    end

    def from_params(params)
      return from_json(params) if params['@id'].present?
      super(params)
    end
    
    def from_json(json)
      @id = json['@id'].split('/canvas_',2)[1]
      @title = json['label']
      @description = json['description']
      @embed_xywh = json['on'].split('#xywh=',2)[1]
      @width = json['resource']['width'].to_i
      @height = json['resource']['height'].to_i
      @image_location = json['resource']['service']['@id'].split("#{Trifle.iiif_service}/",2)[1]
      # Note that image source isn't usually included in iiif. It is needed when layers
      # are serialised in the parent image.
      @image_source = json['metadata'].try(:find) do |md| md['label'] == 'Image source' end .try(:[],'value')
    end

    def parent_image
      container
    end
        
    def image_url(crop: 'full', size: 'full', width: nil, height: nil)
      size = "#{width},#{height}" if width || height
      "#{Trifle.iiif_service}/#{image_location}/#{crop}/#{size}/0/default.jpg"
    end

    def iiif_service(opts={})
      IIIF::Service.new.tap do |service|
        service['@context'] = "http://iiif.io/api/image/2/context.json"
        service['@id'] = "#{Trifle.iiif_service}/#{image_location}"
        service['profile'] = "http://iiif.io/api/image/2/level1.json"
      end
    end
    
    def iiif_resource(opts={})
      IIIF::Presentation::ImageResource.new.tap do |image|
        image['@id'] = image_url
        image.format = 'image/jpeg'
        image.width = width.to_i
        image.height = height.to_i
        image.service = iiif_service(opts)
      end
    end
    
    def iiif_annotation(opts={})
      IIIF::Presentation::Annotation.new.tap do |annotation|
        annotation['@id'] = Trifle.cached_url_helpers.iiif_manifest_iiif_image_annotation_iiif_url(self.manifest, self)
        annotation.label = title if title.present?
        annotation.description = description if description.present?
        annotation.resource = iiif_resource(opts)
        on = Trifle.cached_url_helpers.iiif_manifest_iiif_image_iiif_url(manifest, @container)
        on += "#xywh=#{embed_xywh}" if embed_xywh.present?
        annotation['on'] = on
        annotation.metadata = [{"label" => "Image source", "value" => self.image_source}] if opts[:include_image_source]
      end
    end
    
    def to_iiif(opts={})
      iiif_annotation(opts.reverse_merge({iiif_version: '2.0'}))
    end    
    
  end
end
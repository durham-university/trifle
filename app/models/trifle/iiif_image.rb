module Trifle
  class IIIFImage < ActiveFedora::Base
    include Hydra::Works::WorkBehavior
    include DurhamRails::NoidBehaviour
    include DurhamRails::ArkBehaviour
    include DurhamRails::DestroyFromContainers

    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title
    property :image_location, multiple:false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#image_location')
    property :identifier, predicate: ::RDF::DC.identifier do |index|
      index.as :symbol
    end

    property :width, multiple:false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#image_width')
    property :height, multiple:false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#image_height')


    def to_s
      title
    end

    def as_json(*args)
      super(*args).tap do |json|
        json.merge!({
          'images' => images.map(&:as_json)
        }) if args.first.try(:fetch,:include_children,false)
        parent_id = parent.try(:id)
        json.merge!({'parent_id' => parent_id}) if parent_id.present?
      end
    end    

    def parent
      ordered_by.to_a.find do |m| m.is_a? IIIFManifest end
    end

    def root_collection
      parent.try(:root_collection)
    end

    def allow_destroy?
      true
    end
    
    def iiif_service
      IIIF::Service.new.tap do |service|
        service['@id'] = "#{Trifle.iiif_service}/#{image_location}"
        service['profile'] = "http://iiif.io/api/image/2/level1.json"
      end
    end
    
    def iiif_resource
      IIIF::Presentation::ImageResource.new.tap do |image|
        image['@id'] = "#{Trifle.iiif_service}/#{image_location}/full/full/0/default.jpg"
        image.format = 'image/jpeg'
        image.width = width.to_i
        image.height = height.to_i
        image.service = iiif_service
      end
    end
    
    def iiif_annotation
      IIIF::Presentation::Annotation.new.tap do |annotation|
        annotation['@id'] = Trifle::Engine.routes.url_helpers.iiif_image_url(self, host: Trifle.iiif_host) + '/annotation'
        annotation.resource = iiif_resource
      end
    end
    
    def iiif_canvas
      IIIF::Presentation::Canvas.new.tap do |canvas|
        canvas['@id'] = Trifle::Engine.routes.url_helpers.iiif_image_url(self, host: Trifle.iiif_host)
        canvas.label = title
        canvas.width = width.to_i
        canvas.height = height.to_i
        canvas.images = [iiif_annotation]
        
        canvas.images.each do |image| image['on'] = canvas['@id'] end
      end
    end

    def to_iiif
      iiif_canvas
    end

  end
end

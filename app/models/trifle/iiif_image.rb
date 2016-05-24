module Trifle
  class IIIFImage < ActiveFedora::Base
    include Hydra::Works::WorkBehavior
    include Trifle::ModelBase
    include DurhamRails::NoidBehaviour
    include DurhamRails::ArkBehaviour
    include DurhamRails::DestroyFromContainers
    include DurhamRails::DestroyDependentMembers
    include Trifle::TrackDirtyParentBehaviour

    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title
    property :image_location, multiple:false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#image_location')
    property :image_source, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#image_source')
    property :identifier, predicate: ::RDF::DC.identifier do |index|
      index.as :symbol
    end

    property :width, multiple:false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#image_width')
    property :height, multiple:false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#image_height')


    def as_json(*args)
      super(*args).tap do |json|
        parent_id = parent.try(:id)
        json.merge!({'parent_id' => parent_id}) if parent_id.present?
      end
    end    

    def parent
      ordered_by.to_a.find do |m| m.is_a? IIIFManifest end
    end
    
    def manifest
      parent
    end

    def root_collection
      parent.try(:root_collection)
    end

    def annotation_lists
      ordered_members.to_a.select do |m| m.is_a? IIIFAnnotationList end
    end
    
    def image_url(crop: 'full', size: 'full', width: nil, height: nil)
      size = "#{width},#{height}" if width || height
      "#{Trifle.iiif_service}/#{image_location}/#{crop}/#{size}/0/default.jpg"
    end

    def iiif_service
      IIIF::Service.new.tap do |service|
        service['@id'] = "#{Trifle.iiif_service}/#{image_location}"
        service['profile'] = "http://iiif.io/api/image/2/level1.json"
      end
    end
    
    def iiif_resource
      IIIF::Presentation::ImageResource.new.tap do |image|
        image['@id'] = image_url
        image.format = 'image/jpeg'
        image.width = width.to_i
        image.height = height.to_i
        image.service = iiif_service
      end
    end
    
    def iiif_annotation
      IIIF::Presentation::Annotation.new.tap do |annotation|
        annotation['@id'] = Trifle::Engine.routes.url_helpers.iiif_image_annotation_iiif_url(self, host: Trifle.iiif_host)
        annotation.resource = iiif_resource
        annotation['on'] = Trifle::Engine.routes.url_helpers.iiif_image_iiif_url(self, host: Trifle.iiif_host)
      end
    end
    
    def iiif_canvas(opts={})
      IIIF::Presentation::Canvas.new.tap do |canvas|
        canvas['@id'] = Trifle::Engine.routes.url_helpers.iiif_image_iiif_url(self, host: Trifle.iiif_host)
        canvas.label = title
        canvas.width = width.to_i
        canvas.height = height.to_i
        canvas.images = [iiif_annotation]

        unless opts[:no_annotations]
          canvas.other_content = annotation_lists.map do |al| al.iiif_annotation_list(false) end  if annotation_lists.any?
        end
      end
    end

    def to_iiif(opts={})
      iiif_canvas(opts)
    end

  end
end

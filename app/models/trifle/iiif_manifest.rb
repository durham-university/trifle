module Trifle
  class IIIFManifest < ActiveFedora::Base
    include Hydra::Works::WorkBehavior
    include DurhamRails::NoidBehaviour
    include DurhamRails::ArkBehaviour
    include DurhamRails::WithBackgroundJobs

    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title
    property :image_container_location, multiple:false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#image_container_location')
    property :identifier, predicate: ::RDF::DC.identifier do |index|
      index.as :symbol
    end

    def to_s
      title
    end

    def images
      ordered_members.to_a.select do |m| m.is_a? IIIFImage end
    end

    def add_deposited_image(image)
      self.ordered_members << image
      return self.save
    end
    
    def default_container_location!
      return if self.image_container_location
      if id.nil?
        # assigning a new ark here is just a convenient way to reserve an id
        # which can be used for the container location
        assign_new_ark
        self.image_container_location = (id_from_ark || SecureRandom.hex)
      else
        self.image_container_location = id
      end
    end

    def allow_destroy?
      true
    end
    
    def iiif_sequences
      [IIIF::Presentation::Sequence.new.tap do |sequence|
        sequence['@id'] = Trifle::Engine.routes.url_helpers.iiif_manifest_url(self, host: Trifle.iiif_host) + '/sequences/default'
        sequence.label = 'default'
        sequence.viewing_direction = 'left-to-right'
        sequence.viewing_hint = 'paged'
        sequence.canvases = images.map(&:iiif_canvas)
      end]
    end
    
    def iiif_manifest
      IIIF::Presentation::Manifest.new.tap do |manifest|
        manifest['@id'] = Trifle::Engine.routes.url_helpers.iiif_manifest_url(self, host: Trifle.iiif_host)
        manifest.sequences = iiif_sequences
        manifest.label = self.title
      end
    end
    
  end
end

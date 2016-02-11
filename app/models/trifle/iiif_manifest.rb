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

    def allow_destroy?
      true
    end
    
  end
end

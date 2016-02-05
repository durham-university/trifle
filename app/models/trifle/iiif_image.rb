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

    def to_s
      title
    end

    def parent
      ordered_by.to_a.find do |m| m.is_a? IIIFManifest end
    end

    def allow_destroy?
      true
    end

  end
end

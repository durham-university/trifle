module Trifle
  class IIIFAnnotationList < ActiveFedora::Base
    include Hydra::Works::WorkBehavior
    include Trifle::ModelBase
    include DurhamRails::NoidBehaviour
    include DurhamRails::DestroyFromContainers
    include Trifle::TrackDirtyParentBehaviour

    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title

    def parent
      ordered_by.to_a.find do |m| m.is_a? IIIFImage end
    end
    
    def manifest
      parent.try(:manifest)
    end

    def annotations
      ordered_members.to_a.select do |m| m.is_a? IIIFAnnotation end
    end
        
    def iiif_annotation_list(with_children=true)
      IIIF::Presentation::AnnotationList.new.tap do |annotation_list|
        annotation_list['@id'] = Trifle::Engine.routes.url_helpers.iiif_annotation_list_iiif_url(self, host: Trifle.iiif_host)
        annotation_list.label = title if title.present?
        annotation_list.resources = annotations.map(&:to_iiif) if with_children
      end
    end

    def to_iiif
      iiif_annotation_list
    end    
    
  end
end
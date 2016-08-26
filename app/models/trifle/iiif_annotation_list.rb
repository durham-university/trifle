module Trifle
  class IIIFAnnotationList < ActiveFedora::Base
    include Hydra::Works::WorkBehavior
    include DurhamRails::NoidBehaviour # ModelBase overrides NoidBehaviour, keep this line before include ModelBase
    include Trifle::ModelBase
    include DurhamRails::DestroyFromContainers
    include DurhamRails::DestroyDependentMembers
    include Trifle::TrackDirtyParentBehaviour

    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title

    def parent(reload=false)
      @parent = nil if reload
      @parent ||= ordered_by.to_a.find do |m| m.is_a? IIIFImage end
    end
    
    def manifest
      parent.try(:manifest)
    end

    def annotations
      ordered_members.to_a.select do |m| m.is_a? IIIFAnnotation end .map do |m| m.has_parent!(self) end
    end
        
    def iiif_annotation_list(opts={})
      self.ordered_members.from_solr!
      IIIF::Presentation::AnnotationList.new.tap do |annotation_list|
        annotation_list['@id'] = Trifle::Engine.routes.url_helpers.iiif_annotation_list_iiif_url(self, host: Trifle.iiif_host)
        annotation_list.label = title if title.present?
        annotation_list.resources = annotations.map(&:to_iiif) if opts[:with_children]
      end
    end

    def to_iiif(opts={})
      iiif_annotation_list(opts.reverse_merge({iiif_version: '2.0', with_children: true}))
    end    
    
  end
end
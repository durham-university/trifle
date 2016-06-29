module Trifle
  class IIIFAnnotation < ActiveFedora::Base
    include Hydra::Works::WorkBehavior
    include DurhamRails::NoidBehaviour # ModelBase overrides NoidBehaviour, keep this line before include ModelBase
    include Trifle::ModelBase
    include DurhamRails::DestroyFromContainers
    include Trifle::TrackDirtyParentBehaviour

    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title
    property :format, multiple:false, predicate: ::RDF::Vocab::DC.format
    property :language, multiple:false, predicate: ::RDF::Vocab::DC.language
    property :content, multiple:false, predicate: ::RDF::URI.new('http://www.w3.org/2011/content#chars')
    property :selector, multiple:false, predicate: ::RDF::Vocab::OA.hasSelector
    
    def parent(reload=false)
      @parent = nil if reload
      @parent ||= ordered_by.to_a.find do |m| m.is_a? IIIFAnnotationList end
    end
    
    def manifest
      parent.try(:manifest)
    end
    
    def on_image
      parent.try(:parent)
    end
    
    def iiif_resource
      IIIF::Presentation::Resource.new.tap do |resource|
        resource['@id'] = nil
        resource['@type'] = 'dctypes:Text'
        resource.format = 'text/html'
        resource['chars'] = content
        resource['language'] = language if language.present?
        resource.label = title if title.present?
      end
    end
    
    def iiif_on
      {
        '@type' => 'oa:SpecificResource',
        'full' => Trifle::Engine.routes.url_helpers.iiif_image_iiif_url(on_image, host: Trifle.iiif_host),
      } .tap do |on|
        on['selector'] = JSON.parse(selector) if selector.present?
      end
    end
    
    def iiif_annotation
      IIIF::Presentation::Annotation.new.tap do |annotation|
        annotation['@id'] = Trifle::Engine.routes.url_helpers.iiif_annotation_iiif_url(self, host: Trifle.iiif_host)
        annotation['on'] = iiif_on
        annotation.resource = iiif_resource
      end
    end
    
    def to_iiif
      iiif_annotation
    end
    
    def self.fragment_selector(value)
      "{\"@type\" : \"oa:FragmentSelector\", \"value\" : \"#{value}\" }"
    end
    
  end
end
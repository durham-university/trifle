module Trifle
  class IIIFImage < ActiveFedora::Base
    include Hydra::Works::WorkBehavior
    include DurhamRails::FastContainerItem
#    fast_container_item_pcdm_compatibility
    
    include DurhamRails::NoidBehaviour # ModelBase overrides NoidBehaviour, keep this line before include ModelBase
    include Trifle::ModelBase
    include Trifle::ArkNaanOptionsBehaviour
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

    has_subresource "annotation_lists_iiif", class_name: 'ActiveFedora::File'

    def as_json(*args)
      super(*args).except('serialised_annotations').tap do |json|
        parent_id = parent.try(:id)
        json.merge!({'parent_id' => parent_id}) if parent_id.present?
      end
    end    
    
    def reload
      super
      @annotation_lists = nil
      self
    end

    def parent(reload=false)
      @parent = nil if reload
      #@parent ||= ordered_by.to_a.find do |m| m.is_a? IIIFManifest end
      @parent ||= ordered_item_containers.first
    end
    
    def manifest
      parent
    end

    def root_collection
      parent.try(:root_collection)
    end

    def annotation_lists
      @annotation_lists ||= begin
        iiif = @solr_annotations || annotation_lists_iiif.try(:content)
        if iiif.present?
          json = JSON.parse(iiif)
          json.map do |list_json| Trifle::IIIFAnnotationList.new(self, list_json) end
        else
          []
        end
      end
    end
    
    def serialise_annotations
      self.annotation_lists_iiif ||= ActiveFedora::File.new
      self.annotation_lists_iiif.content = '['
      annotation_lists.each_with_index do |list,index|
        self.annotation_lists_iiif.content << ",\n" if index > 0
        self.annotation_lists_iiif.content << list.to_iiif.to_json(pretty: true)
      end
      self.annotation_lists_iiif.content << ']'      
    end
    
    def image_url(crop: 'full', size: 'full', width: nil, height: nil)
      size = "#{width},#{height}" if width || height
      "#{Trifle.iiif_service}/#{image_location}/#{crop}/#{size}/0/default.jpg"
    end

    def iiif_service(opts={})
      IIIF::Service.new.tap do |service|
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
        annotation.resource = iiif_resource(opts)
        annotation['on'] = Trifle.cached_url_helpers.iiif_manifest_iiif_image_iiif_url(self.manifest, self)
      end
    end
    
    def iiif_canvas(opts={})
      IIIF::Presentation::Canvas.new.tap do |canvas|
        canvas['@id'] = Trifle.cached_url_helpers.iiif_manifest_iiif_image_iiif_url(self.manifest, self)
        canvas.label = title
        canvas.width = width.to_i
        canvas.height = height.to_i
        canvas.images = [iiif_annotation(opts)]

        unless opts[:no_annotations]
          canvas.other_content = annotation_lists.map do |al| al.iiif_annotation_list(opts.merge(with_children: false)) end  if annotation_lists.any?
        end
      end
    end

    def to_iiif(opts={})
      iiif_canvas(opts.reverse_merge({iiif_version: '2.0'}))
    end
    
    def serializable_hash(*args)
      super(*args).merge({'serialised_annotations' => (annotation_lists_iiif.try(:content) || '[]')})
    end    
    
    def init_with_json(json)
      super(json)
      parsed = JSON.parse(json)
      @solr_annotations = parsed['serialised_annotations']
      self
    end

  end
end

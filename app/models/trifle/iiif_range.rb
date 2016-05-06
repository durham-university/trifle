module Trifle
  class IIIFRange < ActiveFedora::Base
    include Hydra::Works::WorkBehavior
    include Trifle::ModelBase
    include DurhamRails::NoidBehaviour
    include DurhamRails::DestroyFromContainers

    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title
#    has_and_belongs_to_many :canvases, predicate: ::RDF::Vocab::IIIF.hasCanvases, class_name: 'Trifle::IIIFImage'

    def manifest
      _parent = parent
      return _parent if parent.is_a?(IIIFManifest)
      return _parent.try(:manifest)
    end
    
    def root_range
      _parent = parent
      return _parent.root_range if parent.is_a?(IIIFRange)
      return self
    end
    
    def parent_range
      _parent = parent
      return _parent if parent.is_a?(IIIFRange)
      return nil
    end

    def parent
      ordered_by.to_a.find do |m| m.is_a?(IIIFManifest) || m.is_a?(IIIFRange) end
    end
    
    def sub_ranges
      ordered_members.to_a.select do |m| m.is_a? IIIFRange end      
    end
    
    def canvases
      ordered_members.to_a.select do |m| m.is_a? IIIFImage end      
    end
    
    def canvas_ids
      canvases.map(&:id)
    end
    
    def canvas_ids=(ids, parent=nil)
      # Note: parent masked
      parent_manifest = case parent
      when IIIFManifest
        parent
      when IIIFRange
        parent.manifest
      else
        self.manifest
      end
      other_members = ordered_members.to_a.reject do |m| m.is_a? IIIFImage end
      all_images = parent_manifest.images.to_a
      canvas_members = ids.map do |id|
        all_images.find do |image| image.id==id end
      end .compact
      self.ordered_members = other_members + canvas_members
      ids # return set value
    end

    def iiif_canvases
      canvases.map do |canvas|
        Trifle::Engine.routes.url_helpers.iiif_image_iiif_url(canvas, host: Trifle.iiif_host)
      end
    end
        
    def iiif_range(with_children=true)
      IIIF::Presentation::Resource.new.tap do |structure|
        structure['@id'] = Trifle::Engine.routes.url_helpers.iiif_range_iiif_url(self, host: Trifle.iiif_host)
        structure['@context'] = nil
        structure['@type'] = 'sc:Range'
        _parent = parent_range
        if _parent.nil?
          structure['viewingHint'] = 'top'
        else
          structure['within'] = Trifle::Engine.routes.url_helpers.iiif_range_iiif_url(_parent, host: Trifle.iiif_host)
        end
        structure['label'] = title
        structure['canvases'] = iiif_canvases if with_children
      end
    end

    def to_iiif
      iiif_range
    end    
    
  end
end
module Trifle
  class IIIFManifest < ActiveFedora::Base
    include Hydra::Works::WorkBehavior
    include Trifle::ModelBase
    include DurhamRails::NoidBehaviour
    include DurhamRails::ArkBehaviour
    include DurhamRails::WithBackgroundJobs
    include DurhamRails::DestroyFromContainers
    include Trifle::SourceRecord

    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title do |index|
      index.as :stored_searchable
    end
    property :image_container_location, multiple:false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#image_container_location')
    property :identifier, predicate: ::RDF::DC.identifier do |index|
      index.as :symbol
    end
    property :date_published, multiple:false, predicate: ::RDF::Vocab::DC.date
    property :author, predicate: ::RDF::Vocab::DC.creator
    property :description, multiple: false, predicate: ::RDF::Vocab::DC.description
    property :licence, multiple: false, predicate: ::RDF::Vocab::DC.rights
    property :attribution, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#attribution')

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
      ordered_by.to_a.find do |m| m.is_a? IIIFCollection end
    end    
    
    def parents
      ordered_by.to_a.select do |m| m.is_a? IIIFCollection end
    end
    
    def parent_ids
      parents.map(&:id)
    end
    
    def manifest
      self
    end

    def root_collection
      parent.try(:root_collection)
    end

    def images
      ordered_members.to_a.select do |m| m.is_a? IIIFImage end
    end
    
    def ranges
      ordered_members.to_a.select do |m| m.is_a? IIIFRange end
    end
    
    def traverse_ranges
      todo=self.ranges.to_a
      ret=[]
      while todo.any?
        s = todo.shift
        ret << s
        todo += s.sub_ranges.to_a
      end
      ret
    end

    def add_deposited_image(image)
      self.ordered_members << image
      return self.save
    end
    
    def treeify_id
      ark = local_ark
      if ark
        (naan, ark_id) = ark[5..-1].split('/')
        [naan, *ark_id.match(/(..)(..)(..)/)[1..-1], ark_id].join('/')
      else
        use_id = id || SecureRandom.hex
        [*use_id.match(/(..)(..)(..)/)[1..-1], use_id].join('/')
      end
    end
    
    def default_container_location!
      return if self.image_container_location
      # assigning a new ark here is just a convenient way to reserve an id
      # which can be used for the container location
      assign_new_ark if id.nil?
      self.image_container_location = treeify_id
    end

    def iiif_ranges
      traverse_ranges.map(&:to_iiif)
    end

    def iiif_sequences
      [IIIF::Presentation::Sequence.new.tap do |sequence|
        sequence['@id'] = Trifle::Engine.routes.url_helpers.iiif_manifest_sequence_iiif_url(self, 'default', host: Trifle.iiif_host)
        sequence.label = 'default'
        sequence.viewing_direction = 'left-to-right'
        sequence.viewing_hint = 'paged'
        sequence.canvases = images.map do |img| img.iiif_canvas end
      end]
    end
    
    def iiif_manifest_stub
      IIIF::Presentation::Manifest.new.tap do |manifest|
        manifest['@id'] = Trifle::Engine.routes.url_helpers.iiif_manifest_iiif_url(self, host: Trifle.iiif_host)
        manifest.label = self.title
      end
    end
        
    def iiif_manifest
      iiif_manifest_stub.tap do |manifest|
        manifest.description = self.description if self.description.present?
        
        # TODO: Move hard coded lincence text to config
        manifest.license = "All images of manuscripts on this website are copyright of the respective repositories and are reproduced with permission.<br>"
        manifest.license += "It is permitted to use this work under the conditions of #{self.licence}. The terms of this licence apply only to the contents of the Durham Priory Library Recreated website.<br>" if self.licence.present? && self.licence.downcase!='all rights reserved'
        manifest.license += "For questions regarding terms of use, requests to purchase reproductions, or further permissions to publish, please contact:<br>Durham Cathedral Library<br>Durham Cathedral<br>The College<br>Durham<br>DH1 3EH<br>library@durhamcathedral.co.uk<br>"
        
        manifest.attribution = self.attribution if self.attribution.present?
        
        metadata = []
        metadata << {"label" => "Author", "value" => self.author} if self.author.present?
        metadata << {"label" => "Published", "value" => self.date_published} if self.date_published.present?
        manifest.metadata = metadata
        
        manifest.structures = iiif_ranges
        
        manifest.sequences = iiif_sequences        
      end
    end
    
    def to_iiif
      iiif_manifest
    end
    
    def to_solr(solr_doc={})
      super(solr_doc).tap do |solr_doc|
        root = root_collection
        if root && root != self
          solr_doc[Solrizer.solr_name('root_collection_id', type: :symbol)] = root.id
        end
      end
    end
    
    def self.all_in_collection(c)
      c = c.id if c.is_a?(Trifle::IIIFCollection)
      self.where(Solrizer.solr_name('root_collection_id', type: :symbol) => c)
    end    
  end
end

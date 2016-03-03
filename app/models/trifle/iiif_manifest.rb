module Trifle
  class IIIFManifest < ActiveFedora::Base
    include Hydra::Works::WorkBehavior
    include Trifle::ModelBase
    include DurhamRails::NoidBehaviour
    include DurhamRails::ArkBehaviour
    include DurhamRails::WithBackgroundJobs

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

    def root_collection
      parent.try(:root_collection)
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

    def iiif_sequences
      [IIIF::Presentation::Sequence.new.tap do |sequence|
        sequence['@id'] = Trifle::Engine.routes.url_helpers.iiif_manifest_url(self, host: Trifle.iiif_host) + '/sequences/default'
        sequence.label = 'default'
        sequence.viewing_direction = 'left-to-right'
        sequence.viewing_hint = 'paged'
        sequence.canvases = images.map(&:iiif_canvas)
      end]
    end
    
    def iiif_manifest_stub
      IIIF::Presentation::Manifest.new.tap do |manifest|
        manifest['@id'] = Trifle::Engine.routes.url_helpers.iiif_manifest_url(self, host: Trifle.iiif_host)
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

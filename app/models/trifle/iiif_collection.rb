module Trifle
  class IIIFCollection < ActiveFedora::Base
    include Hydra::Works::CollectionBehavior
    include Trifle::ModelBase
    include DurhamRails::NoidBehaviour
    include DurhamRails::ArkBehaviour
    include DurhamRails::WithBackgroundJobs
    
    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title do |index|
      index.as :stored_searchable
    end
    property :identifier, predicate: ::RDF::DC.identifier do |index|
      index.as :symbol
    end
    property :description, multiple: false, predicate: ::RDF::Vocab::DC.description
    property :licence, multiple: false, predicate: ::RDF::Vocab::DC.rights
    property :attribution, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#attribution')
    
    def as_json(*args)
      super(*args).tap do |json|
        json.merge!({
          'sub_collections' => sub_collections.map(&:as_json),
          'manifests' => manifests.map(&:as_json)
        }) if args.first.try(:fetch,:include_children,false)
        parent_id = parent.try(:id)
        json.merge!({'parent_id' => parent_id}) if parent_id.present?
      end
    end
    
    def parent
      ordered_by.to_a.find do |m| m.is_a? IIIFCollection end
    end
         
    def root_collection
      parent.try(:root_collection) || self
    end
    
    def sub_collections
      ordered_members.to_a.select do |m| m.is_a? IIIFCollection end
    end

    def manifests
      ordered_members.to_a.select do |m| m.is_a? IIIFManifest end
    end
    
    def iiif_collection_stub
      IIIF::Presentation::Collection.new.tap do |collection|
        collection['@id'] = Trifle::Engine.routes.url_helpers.iiif_collection_url(self, host: Trifle.iiif_host)
        collection.label = self.title
      end
    end
    
    def iiif_collection
      iiif_collection_stub.tap do |collection|
        collection.description = self.description if self.description.present?
        collection.license = self.licence if self.licence.present?
        collection.attribution = self.attribution if self.attribution.present?
        
        collection.collections = sub_collections.to_a.map(&:iiif_collection_stub)
        collection.manifests = manifests.to_a.map(&:iiif_manifest_stub)
        
        parent_collection = self.parent
        collection.within = Trifle::Engine.routes.url_helpers.iiif_collection_url(parent_collection, host: Trifle.iiif_host) if parent_collection.present?
      end
    end
    
    def to_iiif
      iiif_collection
    end
    
    def to_solr(solr_doc={})
      super(solr_doc).tap do |solr_doc|
        root = root_collection
        if root && root != self
          solr_doc[Solrizer.solr_name('root_collection_id', type: :symbol)] = root.id
        end
      end
    end
    
    def self.root_collections
      self.where(Solrizer.solr_name('root_collection_id', type: :symbol) => nil)
    end
    
    def self.all_in_collection(c)
      c = c.id if c.is_a?(Trifle::IIIFCollection)
      self.where(Solrizer.solr_name('root_collection_id', type: :symbol) => c)
    end
    
  end
end
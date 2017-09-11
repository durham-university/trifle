module Trifle
  class IIIFCollection < ActiveFedora::Base
    include Hydra::Works::CollectionBehavior
    include DurhamRails::NoidBehaviour # ModelBase overrides NoidBehaviour, keep this line before include ModelBase
    include Trifle::ModelBase
    include Trifle::ArkNaanOptionsBehaviour
    include Trifle::InheritLogo
    include DurhamRails::WithBackgroundJobs
    include DurhamRails::DestroyFromContainers
    include Trifle::SourceRecord
    include Trifle::MillenniumLinkBehaviour
    
    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title do |index|
      index.as :stored_searchable
    end
    property :digitisation_note, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#digitisation_note')
    property :identifier, predicate: ::RDF::DC.identifier do |index|
      index.as :symbol
    end
    property :description, multiple: false, predicate: ::RDF::Vocab::DC.description
    property :licence, multiple: false, predicate: ::RDF::Vocab::DC.rights
    property :attribution, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#attribution')
    property :logo, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#logo')
    property :keeper, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#keeper')
    
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
    
    def ancestors_from_solr!
      ordered_by_from_solr! unless @parent.present?
      parent.try(:ancestors_from_solr!)
    end    
    
    def parent(reload=false)
      @parent = nil if reload
      @parent ||= ordered_by.to_a.find do |m| m.is_a? IIIFCollection end
    end
    
    def parents
      Array.wrap(parent)
    end
    
    def parent_ids
      parents.map(&:id)
    end
    
    def public_source_link
      super || parent.try(:public_source_link)
    end    
         
    def root_collection
      parent.try(:root_collection) || self
    end
    
    def sub_collections
      ordered_members.to_a.select do |m| m.is_a? IIIFCollection end .each do |m| m.has_parent!(self) end
    end

    def manifests
      ordered_members.to_a.select do |m| m.is_a? IIIFManifest end .each do |m| m.has_parent!(self) end
    end
    
    def iiif_collection_stub(opts={})
      IIIF::Presentation::Collection.new.tap do |collection|
        collection['@id'] = Trifle::Engine.routes.url_helpers.iiif_collection_iiif_url(self, host: Trifle.iiif_host)
        collection.label = self.title
      end
    end
    
    def iiif_collection(opts={})
      iiif_collection_stub(opts).tap do |collection|
        if self.description.present? || self.digitisation_note.present?
          collection.description = [self.description,self.digitisation_note].select(&:present?).join("\n")
        end
        collection.license = self.licence if self.licence.present?
        collection.attribution = self.attribution if self.attribution.present?
        
        source_link = public_source_link
        collection['related'] = source_link if source_link        
        
        _inherited_logo = inherited_logo
        collection.logo = _inherited_logo if _inherited_logo
        
        collection.collections = sub_collections.to_a.map do |c| c.iiif_collection_stub(opts) end
        collection.manifests = manifests.to_a.map do |m| m.iiif_manifest_stub(opts) end
        
        parent_collection = self.parent
        collection.within = Trifle::Engine.routes.url_helpers.iiif_collection_iiif_url(parent_collection, host: Trifle.iiif_host) if parent_collection.present?
      end
    end
    
    def to_iiif(opts={})
      iiif_collection(opts.reverse_merge({iiif_version: '2.0'}))
    end
    
    def to_solr(solr_doc={})
      super(solr_doc).tap do |solr_doc|
        root = root_collection
        if root && root != self
          solr_doc[Solrizer.solr_name('root_collection_id', type: :symbol)] = root.id
        end
      end
    end
    
    def self.index_collection_iiif(opts={})
      IIIF::Presentation::Collection.new.tap do |collection|
        config = (Trifle.config[:index_collection] || Trifle.config['index_collection'] || {}).with_indifferent_access        
        collection['@id'] = Trifle::Engine.routes.url_helpers.iiif_collection_index_iiif_url(host: Trifle.iiif_host)
        collection.label = config[:label] || 'Collection index'
        collection.description = config[:description] || nil
        collection.license = config[:licence] || nil
        collection.attribution = config[:attribution] || nil
        collection.logo = config[:logo] || nil
        collection.collections = root_collections.to_a.map do |c| c.iiif_collection_stub(opts) end
      end        
    end
    
    def self.root_collections
      self.where(Solrizer.solr_name('root_collection_id', type: :symbol) => nil)
    end
    
    def self.all_in_collection(c)
      c = c.id if c.is_a?(Trifle::IIIFCollection)
      self.where(Solrizer.solr_name('root_collection_id', type: :symbol) => c)
    end
  
    private 
    
      def noid_minter
        @noid_minter ||= noid_minter_with_prefix('c', 'collection')
      end
  
  end
end
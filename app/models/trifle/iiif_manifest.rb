module Trifle
  class IIIFManifest < ActiveFedora::Base
#    include Hydra::Works::WorkBehavior
    include DurhamRails::FastContainer
    fast_container_pcdm_compatibility
    
    include DurhamRails::NoidBehaviour # ModelBase overrides NoidBehaviour, keep this line before include ModelBase
    include Trifle::ModelBase
    include Trifle::ArkNaanOptionsBehaviour
    include DurhamRails::WithBackgroundJobs
    include DurhamRails::DestroyFromContainers
    include DurhamRails::DestroyDependentMembers
    include Trifle::InheritLogo
    include Trifle::TrackDirtyStateBehaviour
    include Trifle::SourceRecord

    property :title, multiple:false, predicate: ::RDF::Vocab::DC.title do |index|
      index.as :stored_searchable
    end
    property :digitisation_note, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#digitisation_note')
    property :image_container_location, multiple:false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#image_container_location')
    property :identifier, predicate: ::RDF::DC.identifier do |index|
      index.as :symbol
    end
    property :date_published, multiple:false, predicate: ::RDF::Vocab::DC.date
    property :author, predicate: ::RDF::Vocab::DC.creator
    property :description, multiple: false, predicate: ::RDF::Vocab::DC.description
    property :licence, multiple: false, predicate: ::RDF::Vocab::DC.rights
    property :attribution, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#attribution')

    has_subresource "ranges_iiif", class_name: 'ActiveFedora::File'

    def as_json(*args)
      super(*args).except('serialised_ranges').tap do |json|
        json.merge!({
          'images' => images.map(&:as_json)
        }) if args.first.try(:fetch,:include_children,false)
        parent_id = parent.try(:id)
        json.merge!({'parent_id' => parent_id}) if parent_id.present?
      end
    end    
    
    def reload
      super
      @ranges = nil
      @ranges_flat = nil
      self
    end
    
    def has_parent!(parent)
      # Can't set parent of IIIF Manifest. It can have multiple parents.
      # We can still cache one parent and return it if only a single one is needed.
      @one_parent = parent
    end

    def parent
      return @one_parent if @one_parent.present?
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
      ordered_members.to_a.select do |m| m.is_a? IIIFImage end .map do |m| m.has_parent!(self) end
    end
    
    def ranges_flat
      @ranges_flat ||= []
    end
    
    def ranges
      @ranges ||= begin
        @ranges_flat ||= []
        iiif = @solr_ranges || ranges_iiif.try(:content)
        if iiif.present?
          ret = []
          json = JSON.parse(iiif)
          json.each do |range_json| 
            range = Trifle::IIIFRange.new(self, range_json) 
            @ranges_flat << range
            ret << range if range_json['viewingHint'] == 'top'
          end
          ret
        else
          []
        end
      end
    end
    def ranges=(rs)
      @ranges ||= []
      @ranges.replace(rs)
    end
        
    def serialise_ranges
      # traverse_ranges below will need access to parsed ranges. Make sure
      # that they have been deserialised before resetting ranges_iiif.content
      ranges 
      self.ranges_iiif ||= ActiveFedora::File.new
      self.ranges_iiif.content = '['
      traverse_ranges.each_with_index do |range,index|
        self.ranges_iiif.content << ",\n" if index > 0
        self.ranges_iiif.content << range.to_iiif.to_json(pretty: true)
      end
      self.ranges_iiif.content << ']'      
    end
    
    def traverse_ranges
      todo=self.ranges.dup
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

    def iiif_ranges(opts={})
      traverse_ranges.map do |r| r.to_iiif(opts) end
    end

    def iiif_sequences(opts={})
      [IIIF::Presentation::Sequence.new.tap do |sequence|
        sequence['@id'] = Trifle::Engine.routes.url_helpers.iiif_manifest_sequence_iiif_url(self, 'default', host: Trifle.iiif_host)
        sequence.label = 'default'
        sequence.viewing_direction = 'left-to-right'
        sequence.viewing_hint = 'paged'
        sequence.canvases = images.map do |img| img.iiif_canvas(opts) end
      end]
    end
    
    def iiif_manifest_stub(opts={})
      IIIF::Presentation::Manifest.new.tap do |manifest|
        manifest['@id'] = Trifle::Engine.routes.url_helpers.iiif_manifest_iiif_url(self, host: Trifle.iiif_host)
        manifest.label = self.title
      end
    end
        
    def iiif_manifest(opts={})
      self.ordered_members.from_solr!
      iiif_manifest_stub(opts).tap do |manifest|
        if self.description.present? || self.digitisation_note.present?
          manifest.description = [self.description,self.digitisation_note].select(&:present?).join("\n")
        end
        
        source_link = public_source_link
        manifest['related'] = source_link if source_link        
        
        _inherited_logo = inherited_logo
        manifest.logo = _inherited_logo if _inherited_logo
        
        manifest.license = self.licence if self.licence.present?
        
        manifest.attribution = self.attribution if self.attribution.present?
        
        metadata = []
        metadata << {"label" => "Author", "value" => self.author} if self.author.present?
        metadata << {"label" => "Published", "value" => self.date_published} if self.date_published.present?
        manifest.metadata = metadata
        
        manifest.structures = iiif_ranges(opts)
        
        manifest.sequences = iiif_sequences(opts)
        
        _parent = parent
        manifest.within = Trifle::Engine.routes.url_helpers.iiif_collection_iiif_url(_parent, host: Trifle.iiif_host) if _parent
      end
    end
    
    def to_iiif(opts={})
      iiif_manifest(opts.reverse_merge({iiif_version: '2.0'}))
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

    
    def serializable_hash(*args)
      super(*args).merge({'serialised_ranges' => (ranges_iiif.try(:content) || '[]')})
    end    
    
    def init_with_json(json)
      super(json)
      parsed = JSON.parse(json)
      @solr_ranges = parsed['serialised_ranges']
      self
    end
    
    
    private 
    
      def noid_minter
        @noid_minter ||= noid_minter_with_prefix('m', 'manifest')
      end
    
  end
end

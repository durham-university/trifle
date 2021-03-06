module Trifle
  class IIIFRange
    extend ActiveModel::Naming
    include DurhamRails::NoidBehaviour # ModelBase overrides NoidBehaviour, keep this line before include ModelBase
    include Trifle::ModelBase
    
    attr_accessor :id, :title, :manifest
    attr_reader :sub_ranges, :canvases
    
    def initialize(manifest=nil, json_or_params=nil)
      if json_or_params.nil? && manifest.is_a?(Hash)
        json_or_params = manifest
        manifest = nil
      end
      @manifest = manifest
      json_or_params ||= {}
      if json_or_params.key?('@id')
        from_json(json_or_params)
      else
        from_params(json_or_params)
      end
    end
    
    def save
      # Note that this saves the entire manifest where the range is contained
      assign_id!
      _manifest = manifest
      _manifest.serialise_ranges
      _manifest.save
    end
    def assign_id!
      @id = assign_id unless id.present?
    end
    alias_method :save!, :save
    def update(attributes={})
      self.title = attributes['title'] if attributes.key?('title')
      self.canvas_ids = attributes['canvas_ids'] if attributes.key?('canvas_ids')
      save
    end
    def destroy
      if parent.is_a?(IIIFManifest)
        parent.ranges.delete(self)
      else
        parent.sub_ranges.delete(self)
      end
      @manifest.serialise_ranges
      @manifest.save
    end

    def assign_id
      "#{manifest.id}_#{super}"
    end
    
    # compatibility methods to make this look like ActiveRecord and play nice with things
    def attributes
      { "id" => id, "title" => title }
    end    
    def [](attribute)
      attributes[attribute.to_s]
    end
    def self.attribute_names
      ["id", "title"]
    end
    def self.multiple?(field)
      false
    end
    def self.reflect_on_association(field)
      nil
    end
    def to_model
      self
    end
    def persisted?
      id.present? && @manifest && @manifest.persisted?
    end
    def new_record?
      !persisted?
    end
    alias_method :to_param, :id
    def to_key
      [to_param]
    end
    def errors
      @errors ||= ActiveModel::Errors.new(self)
    end
    def valid?
      true
    end
    def validate!
    end
    
    def self.find(id)
      man_id = id.split('_').first
      man = Trifle::IIIFManifest.find(man_id)
      man.traverse_ranges.each do |range|
        return range if range.id == id
      end
      raise ActiveFedora::ObjectNotFoundError
    end
    
    def self.load_instance_from_solr(id)
      man_id = id.split('_').first
      man = Trifle::IIIFManifest.load_instance_from_solr(man_id)
      man.ordered_members.from_solr!
      man.traverse_ranges.each do |range|
        return range if range.id == id
      end
      raise ActiveFedora::ObjectNotFoundError
    end
    
    def from_params(params)
      @id = params[:id]
      @title = params[:title]
      @sub_ranges = []
      @canvases = []
      if params.key?(:manifest)
        @manifest = params[:manifest]
        @parent = Trifle::IIIFManifest.find(@parent) if @parent.is_a?(String)
      end
    end
    
    def from_json(json)
      # This only works with IIIF v 2.0
      @id = json['@id'].split('/').last
      @title = json['label']
      @sub_ranges = nil
      @sub_range_ids = (json['ranges'] || []).map do |range_uri|
        range_uri.split('/').last
      end
      @canvases = nil
      @canvas_ids = (json['canvases'] || []).map do |canvas_uri|
        canvas_uri.split('/').last        
      end
    end
    
    def sub_ranges
      @sub_ranges ||= begin
        _ranges_flat = manifest.ranges_flat
        @sub_range_ids.map do |range_id|
          _ranges_flat.find do |r| r.id == range_id end
        end
      end
    end
    def sub_ranges=(srs)
      @sub_ranges ||= []
      @sub_ranges.replace(srs)
    end
    
    def canvases
      @canvases ||= begin
        _images = manifest.images
        @canvas_ids.map do |canvas_id|
          _images.find do |i| i.id == canvas_id end
        end
      end
    end
    
    def canvases=(cs)
      @canvases ||= []
      @canvases.replace(cs)
    end

    def manifest
      @manifest
    end
    
    def parent
      # NOTE: this could be optimised; maybe also find root_range while at it
      @parent ||= begin
        if @manifest.ranges.include?(self)
          @manifest
        else
          manifest.traverse_ranges.find do |r| r.sub_ranges.include?(self) end
        end
      end
    end
    
    def root_range
      return parent.root_range if parent.is_a?(IIIFRange)
      return self
    end
    
    def parent_range
      return parent if parent.is_a?(IIIFRange)
      return nil
    end
    
    def sub_range_ids
      # don't get full sub_ranges if we don't need to
      return sub_ranges.map(&:id) if @sub_ranges
      @sub_range_ids.try(:dup) || []
    end

    def canvas_ids
      # don't get full canvases if we don't need to
      return canvases.map(&:id) if @canvases
      @canvas_ids.try(:dup) || []
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
      all_images = parent_manifest.images.to_a
      canvas_members = ids.map do |id|
        all_images.find do |image| image.id==id end
      end .compact
      self.canvases.replace(canvas_members)
      ids # return set value
    end

    def iiif_canvases
      canvas_ids.map do |canvas_id|
        Trifle.cached_url_helpers.iiif_manifest_iiif_image_iiif_url(manifest, canvas_id)
      end
    end
    
    def iiif_subranges
      sub_range_ids.map do |range_id|
        Trifle.cached_url_helpers.iiif_manifest_iiif_range_iiif_url(manifest, range_id)
      end
    end
        
    def iiif_range(opts={})
      version = opts.fetch(:iiif_version,'2.0').to_f 
      IIIF::Presentation::Resource.new.tap do |structure|
        structure['@id'] = Trifle.cached_url_helpers.iiif_manifest_iiif_range_iiif_url(manifest, self)
        structure['@context'] = nil
        structure['@type'] = 'sc:Range'
        _parent = parent_range
        if _parent.nil?
          structure['viewingHint'] = 'top'
        elsif version < 2.0
          structure['within'] = Trifle.cached_url_helpers.iiif_manifest_iiif_range_iiif_url(manifest, _parent)
        end
        structure['label'] = title
        structure['canvases'] = iiif_canvases if opts[:with_children]
        structure['ranges'] = iiif_subranges if version >= 2.0 && opts[:with_children]
      end
    end
    
    def to_iiif(opts={})
      iiif_range(opts.reverse_merge({iiif_version: '2.0', with_children: true}))
    end    
    
  end
end
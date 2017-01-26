module Trifle
  class IIIFAnnotationList
    extend ActiveModel::Naming
    include DurhamRails::NoidBehaviour # ModelBase overrides NoidBehaviour, keep this line before include ModelBase
    include Trifle::ModelBase
    
    attr_accessor :id, :title, :annotations, :parent
    
    def initialize(parent=nil, json_or_params=nil)
      if json_or_params.nil? && parent.is_a?(Hash)
        json_or_params = parent
        parent = nil
      end
      @parent = parent
      json_or_params ||= {}
      if json_or_params.key?('@id')
        from_json(json_or_params)
      else
        from_params(json_or_params)
      end
    end
    
    def save
      # Note that this saves the entire image where the annotation is contained
      assign_id!
      parent.serialise_annotations
      parent.save
    end
    def assign_id!
      @id = assign_id unless id.present?
    end
    alias_method :save!, :save
    def update(attributes={})
      self.title = attributes['title'] if attributes.key?('title')
      save
    end
    def destroy
      parent.annotation_lists.delete(self)
      parent.serialise_annotations
      parent.save
    end
    
    def assign_id
      "#{@parent.id}_#{super}"
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
      id.present? && @parent && @parent.persisted?
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
      image_id = id.split('_').first
      image = Trifle::IIIFImage.find(image_id)
      image.annotation_lists.each do |list| return list if list.id == id end
      raise ActiveFedora::ObjectNotFoundError
    end
    
    def self.load_instance_from_solr(id)
      image_id = id.split('_').first
      image = Trifle::IIIFImage.load_instance_from_solr(image_id)
      image.annotation_lists.each do |list| return list if list.id == id end
      raise ActiveFedora::ObjectNotFoundError      
    end
    
    def from_params(params)
      @id = params[:id]
      @title = params[:title]
      @annotations = []
      if params.key?(:parent)
        @parent = params[:parent]
        @parent = Trifle::IIIFImage.find(@parent) if @parent.is_a?(String)
      end
    end
    
    def from_json(json)
      @id = json['@id'].split('/').last
      @title = json['label']
      @annotations = (json['resources'] || []).map do |annotation_json|
        Trifle::IIIFAnnotation.new(self, annotation_json)
      end
    end
    
    def manifest
      parent.try(:manifest)
    end

    def iiif_annotation_list(opts={})
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
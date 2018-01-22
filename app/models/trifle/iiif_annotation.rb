module Trifle
  class IIIFAnnotation
    extend ActiveModel::Naming
    include DurhamRails::NoidBehaviour # ModelBase overrides NoidBehaviour, keep this line before include ModelBase
    include Trifle::ModelBase

    attr_accessor :id, :title, :format, :language, :content, :selector, :parent
    
    def initialize(parent=nil, json_or_params=nil)
      if json_or_params.nil? && parent.is_a?(Hash)
        json_or_params = parent
        parent = nil
      end
      @parent = parent
      json_or_params ||= {}      
      from_params(json_or_params)
    end
    
    def save
      # Note that this saves the entire image where the annotation is contained
      assign_id!
      img = on_image
      img.serialise_annotations
      img.save
    end
    def assign_id!
      @id = assign_id unless id.present?
    end
    alias_method :save!, :save
    def update(attributes={})
      self.title = attributes['title'] if attributes.key?('title')
      self.format = attributes['format'] if attributes.key?('format')
      self.language = attributes['language'] if attributes.key?('language')
      self.content = attributes['content'] if attributes.key?('content')
      self.selector = attributes['selector'] if attributes.key?('selector')
      save
    end
    def destroy
      img = on_image
      parent.annotations.delete(self)
      img.serialise_annotations
      img.save
    end

    def assign_id
      "#{on_image.id}_#{super}"
    end
    
    # compatibility methods to make this look like ActiveRecord and play nice with things
    def attributes
      { "id" => id, "title" => title, "format" => format, "language" => language, "content" => content, "selector" => selector }
    end    
    def [](attribute)
      attributes[attribute.to_s]
    end
    def self.attribute_names
      ["id", "title", "format", "language", "content", "selector"]
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
    
    def ancestors_from_solr!
      parent.ancestors_from_solr!
    end    
    
    def self.find(id)
      image_id = id.split('_').first
      image = Trifle::IIIFImage.find(image_id)
      image.annotation_lists.each do |list|
        list.annotations.each do |anno|
          return anno if anno.id == id
        end
      end
      raise ActiveFedora::ObjectNotFoundError
    end
    
    def self.load_instance_from_solr(id)
      image_id = id.split('_').first
      image = Trifle::IIIFImage.load_instance_from_solr(image_id)
      image.annotation_lists.each do |list|
        list.annotations.each do |anno|
          return anno if anno.id == id
        end
      end
      raise ActiveFedora::ObjectNotFoundError
    end
    
    def from_params(params)
      @id = params['@id'].try(:split,'/').try(:last) || params[:id] || params['id']
      @title = params['resource'].try(:[],'label') || params[:title] || params['title']
      @content = params['resource'].try(:[],'chars') || params[:content] || params['content']
      @language = params['resource'].try(:[],'language') || params[:language] || params['language']
      @format = params['resource'].try(:[],'format') || params[:format] || params['format']
      @selector = Array.wrap(params['on']).first.try(:[],'selector') || params[:selector] || params['selector']
      @selector = @selector.to_json if @selector && !@selector.is_a?(String)
      if params.key?(:parent) || params.key?('parent')
        @parent = params[:parent] || params['parent']
        @parent = Trifle::IIIFAnnotationList.find(@parent) if @parent.is_a?(String)
      end
    end

    def as_json(*args)
      {
        'id' => id, 
        'title' => title,
        'content' => content,
        'language' => language,
        'format' => self.format,
        'selector' => selector
      }
    end    

    def from_json(json)
      from_params(json)
    end

    def manifest
      parent.try(:manifest)
    end
    
    def on_image
      parent.try(:parent)
    end
    
    def iiif_resource(opts={})
      IIIF::Presentation::Resource.new.tap do |resource|
        resource['@id'] = nil
        resource['@type'] = 'dctypes:Text'
        resource.format = 'text/html'
        resource['chars'] = content
        resource['language'] = language if language.present?
        resource.label = title if title.present?
      end
    end
    
    def iiif_on(opts={})
      on = {
        '@type' => 'oa:SpecificResource',
        'full' => Trifle.cached_url_helpers.iiif_manifest_iiif_image_iiif_url(manifest, on_image),
      } .tap do |on|
        on['selector'] = JSON.parse(selector) if selector.present?
      end
      # According to specs, 'on' can be a single value or an array. However, Mirador annotation
      # DualStrategy won't work without it being an array. On the other hand, other strategies
      # won't work with an array. So wrap it in an array only when Mirador needs it. The new
      # versions of Mirador should
      if on['selector'].try(:[],'@type') == 'oa:Choice'
        on = [on]
      end
      on
    end
    
    def iiif_annotation(opts={})
      IIIF::Presentation::Annotation.new.tap do |annotation|
        annotation['@id'] = Trifle.cached_url_helpers.iiif_manifest_iiif_annotation_iiif_url(manifest, self)
        annotation['on'] = iiif_on(opts)
        annotation.resource = iiif_resource(opts)
      end
    end
    
    def to_iiif(opts={})
      iiif_annotation(opts.reverse_merge({iiif_version: '2.0'}))
    end
    
    def self.fragment_selector(value)
      "{\"@type\" : \"oa:FragmentSelector\", \"value\" : \"#{value}\" }"
    end
    
  end
end
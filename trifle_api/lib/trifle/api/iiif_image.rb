module Trifle
  module API
    class IIIFImage
      include ModelBase

      attr_accessor :parent_id, :identifier, :description, :source_record
      attr_accessor :width, :height, :image_location, :image_source

      def initialize
        super
      end

      def parent
        @parent ||= begin
          if parent_id
            Trifle::API::IIIFManifest.find(parent_id)
          else
            nil
          end
        end
      end

      def from_json(json)
        super(json)
        @identifier = json['identifier']
        @source_record = json['source_record']
        @description = json['description']
        @parent_id = json['parent_id']
        @width = json['width']
        @height = json['height']
        @image_location = json['image_location']
        @image_source = json['image_source']
      end

      def as_json(*args)
        json = super(*args)
        json['identifier'] = @identifier
        json['source_record'] = @source_record
        json['date_published'] = @date_published
        json['description'] = @description
        json['parent_id'] = @parent_id
        json['width'] = @width
        json['height'] = @height
        json['image_location'] = @image_location
        json['image_source'] = @image_source
        json
      end

      def self.all_in_source(source)
        return all_in_source_local(source) if local_mode?
        response = self.get("/image.json?in_source=#{CGI.escape(source)}&per_page=all")
        raise FetchError, "Error fetching images in source: #{response.code} - #{response.message}" unless response.code == 200
        json = JSON.parse(response.body)
        json['resources'].map do |resource_json|
          self.from_json(resource_json)
        end        
      end
      
      def self.all_in_source_local(source)
        local_class.find_from_source(source).to_a.map do |resource|
          self.from_json(resource.as_json)
        end
      end

      def self.model_name
        'image'
      end
      
      def self.local_class
        'Trifle::IIIFImage'.constantize
      end

    end
  end
end

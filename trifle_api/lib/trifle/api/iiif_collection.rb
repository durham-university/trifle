module Trifle
  module API
    class IIIFCollection
      include ModelBase
      include APIAuthentication

      attr_accessor :identifier, :description, :licence, :attribution

      def initialize
        super
        @sub_collections = nil
        @manifests = nil
      end

      def from_json(json)
        super(json)
        @identifier = json['identifier']
        @description = json['description']
        @licence = json['licence']
        @attribution = json['attribution']
        @sub_collections = json['sub_collections'].map do |c_json| Trifle::API::IIIFCollection.from_json(c_json) end if json.key?('sub_collections')
        @manifests = json['manifests'].map do |m_json| Trifle::API::IIIFManifest.from_json(m_json) end if json.key?('manifests')
      end

      def as_json(*args)
        json = super(*args)
        json['identifier'] = @identifier
        json['description'] = @description
        json['licence'] = @licence
        json['attribution'] = @attribution
        json['sub_collections'] = @sub_collections.map(&:as_json) if @sub_collections
        json['manifests'] = @manifests.map(&:as_json) if @manifests
        json
      end
      
      def sub_collections
        fetch unless @sub_collections
        @sub_collections
      end

      def manifests
        fetch unless @manifests
        @manifests
      end
      
      def full
        fetch unless @files
      end      

      def self.all
        return all_local if local_mode?
        response = self.get('/iiif_collections.json')
        raise FetchError, "Error fetching collections: #{response.code} - #{response.message}" unless response.code == 200
        json = JSON.parse(response.body)
        json['resources'].map do |resource_json|
          self.from_json(resource_json)
        end
      end

      def self.all_local
        local_class.root_collections.to_a.map do |resource|
          self.from_json(resource.as_json)
        end
      end

      def self.model_name
        'iiif_collections'
      end

    end
  end
end

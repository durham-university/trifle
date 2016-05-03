module Trifle
  module API
    class IIIFCollection
      include ModelBase

      attr_accessor :parent_id, :identifier, :description, :licence, :attribution

      def initialize
        super
        @sub_collections = nil
        @manifests = nil
      end

      def parent
        @parent ||= begin
          if parent_id
            Trifle::API::IIIFCollection.find(parent_id)
          else
            nil
          end
        end
      end

      def from_json(json)
        super(json)
        @identifier = json['identifier']
        @description = json['description']
        @licence = json['licence']
        @attribution = json['attribution']
        @sub_collections = json['sub_collections'].map do |c_json| Trifle::API::IIIFCollection.from_json(c_json) end if json.key?('sub_collections')
        @manifests = json['manifests'].map do |m_json| Trifle::API::IIIFManifest.from_json(m_json) end if json.key?('manifests')
        @parent_id = json['parent_id']
      end

      def as_json(*args)
        json = super(*args)
        json['identifier'] = @identifier
        json['description'] = @description
        json['licence'] = @licence
        json['attribution'] = @attribution
        json['sub_collections'] = @sub_collections.map(&:as_json) if @sub_collections
        json['manifests'] = @manifests.map(&:as_json) if @manifests
        json['parent_id'] = @parent_id
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

      # Note that .all is really only all root level collections
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
      
      def self.all_in_collection(collection)
        return all_in_collection_local(collection) if local_mode?
        response = self.get("/iiif_collections/#{collection.id}.json?full_collection_list=1")
        raise FetchError, "Error fetching full collection list: #{response.code} - #{response.message}" unless response.code == 200
        json = JSON.parse(response.body)
        json['resources'].map do |resource_json|
          self.from_json(resource_json)
        end
      end
      
      def self.all_in_collection_local(collection)
        collection_local = Trifle::API::IIIFCollection.local_class.find(collection.id)
        local_class.all_in_collection(collection_local).map do |resource|
          self.from_json(resource.as_json)
        end
      end
      
      def self.model_name
        'iiif_collections'
      end

    end
  end
end

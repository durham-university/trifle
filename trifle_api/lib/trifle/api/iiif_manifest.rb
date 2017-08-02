module Trifle
  module API
    class IIIFManifest
      include ModelBase

      attr_accessor :image_container_location
      attr_accessor :parent_id, :digitisation_note, :identifier, :date_published, :author, :description, :licence, :attribution, :source_record, :job_tag

      def initialize
        super
        @images = nil
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
        @digitisation_note = json['digitisation_note']
        @image_container_location = json['image_container_location']
        @identifier = json['identifier']
        @source_record = json['source_record']
        @date_published = json['date_published']
        @author = json['author']
        @description = json['description']
        @licence = json['licence']
        @attribution = json['attribution']
        @images = json['images'].map do |m_json| Trifle::API::IIIFImage.from_json(m_json) end if json.key?('images')
        @parent_id = json['parent_id']
        @job_tag = json['job_tag']
      end

      def as_json(*args)
        json = super(*args)
        json['digitisation_note'] = @digitisation_note
        json['image_container_location'] = @image_container_location
        json['identifier'] = @identifier
        json['source_record'] = @source_record
        json['date_published'] = @date_published
        json['author'] = @author
        json['description'] = @description
        json['licence'] = @licence
        json['attribution'] = @attribution
        json['parent_id'] = @parent_id
        json['job_tag'] = @job_tag
        json['images'] = @images.map(&:as_json) if @images
        json
      end

      def images
        fetch unless @images
        @images
      end
      
      def full
        fetch unless @images
      end      

      def self.all
        # TODO: handle paging properly
        return all_local if local_mode?
        response = self.get('/manifest.json?per_page=1000')
        raise FetchError, "Error fetching manifests: #{response.code} - #{response.message}" unless response.code == 200
        json = JSON.parse(response.body)
        json['resources'].map do |resource_json|
          self.from_json(resource_json)
        end
      end

      def self.all_local
        local_class.all.to_a.map do |resource|
          self.from_json(resource.as_json)
        end
      end
      
      def self.all_in_collection(collection)
        return all_in_collection_local(collection) if local_mode?
        response = self.get("/collection/#{collection.id}.json?full_manifest_list=1")
        raise FetchError, "Error fetching full manifest list: #{response.code} - #{response.message}" unless response.code == 200
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
      
      def self.all_in_source(source)
        return all_in_source_local(source) if local_mode?
        response = self.get("/manifest.json?in_source=#{CGI.escape(source)}&per_page=all")
        raise FetchError, "Error fetching manifests in source: #{response.code} - #{response.message}" unless response.code == 200
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
        'manifest'
      end
      
      def self.local_class
        'Trifle::IIIFManifest'.constantize
      end

      # NOTE: can give :ark_naan in manifest_metadata to set the naan used for ark
      def self.deposit_new(parent, deposit_items,manifest_metadata={})
        return deposit_new_local(parent, deposit_items,manifest_metadata) if local_mode?
        parent = parent.id if parent.respond_to?(:id)
        deposit_items_io = MultiPartIO.new(deposit_items.to_json)
        response = self.post("/collection/#{CGI.escape parent}/manifest/deposit.json", {body: {deposit_items: deposit_items_io, iiif_manifest: manifest_metadata}})
        json = JSON.parse(response.body)
        {
          resource: json['resource'] ? self.from_json(json['resource']) : nil,
          status: json['status'],
          message: json['message']
        }
      end
      
      def self.deposit_into(manifest, deposit_items)
        return deposit_into_local(manifest, deposit_items) if local_mode?
        manifest = manifest.id if manifest.respond_to?(:id)
        deposit_items_io = MultiPartIO.new(deposit_items.to_json)
        response = self.post("/manifest/#{CGI.escape manifest}/deposit.json", {body: {deposit_items: deposit_items_io}})
        json = JSON.parse(response.body)
        {
          resource: json['resource'] ? self.from_json(json['resource']) : nil,
          status: json['status'],
          message: json['message']
        }
      end
                
      def self.deposit_into_local(manifest, deposit_items)
        manifest = manifest.id if manifest.respond_to?(:id)
        local_manifest = Trifle::IIIFManifest.find(manifest)
        job = Trifle::DepositJob.new(resource: local_manifest, deposit_items: deposit_items)
        job.queue_job
        {
          resource: self.from_json(local_manifest.as_json),
          status: 'ok',
          message: nil
        }
      end
      
      def self.deposit_new_local(parent, deposit_items,manifest_metadata={})
        parent = parent.id if parent.respond_to?(:id)
        manifest_metadata['title'] ||= "New manifest #{DateTime.now.strftime('%F %R')}"
        local_collection = Trifle::IIIFCollection.find(parent)
        local_manifest = Trifle::IIIFManifest.new()
        local_manifest.attributes = manifest_metadata.reject do |key,value| value.nil? end

        local_manifest.default_container_location!
        local_manifest.refresh_from_source if local_manifest.source_record  && local_manifest.source_record.strip.length>0
        local_collection.ordered_members << local_manifest
        local_collection.save
        local_manifest.save
        
        job = Trifle::DepositJob.new(resource: local_manifest, deposit_items: deposit_items)
        job.queue_job
        {
          resource: self.from_json(local_manifest.as_json),
          status: 'ok',
          message: nil
        }
      end
      
      class MultiPartIO
        attr_reader :original_filename, :content_type, :length
        def initialize(content)
          @content = content.to_s
          @length = @content.length
          @io = StringIO.new(@content)
          @original_filename = 'images.json'
          @content_type = 'application/json'
        end
        def read(*args,&block)
          # need to actually define this so that respond_to?(:read) returns true
          @io.read(*args,&block)
        end
        def method_missing(method,*args,&block)
          @io.send(methods,*args,&block)
        end
      end

    end
  end
end

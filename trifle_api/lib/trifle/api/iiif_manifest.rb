module Trifle
  module API
    class IIIFManifest
      include ModelBase
      include APIAuthentication

      attr_accessor :image_container_location
      attr_accessor :identifier

      def initialize
        super
      end

      def from_json(json)
        super(json)
        @image_container_location = json['image_container_location']
        @identifier = json['identifier']
      end

      def as_json(*args)
        json = super(*args)
        json[:image_container_location] = @image_container_location
        json[:identifier] = @identifier
        json
      end

      def self.all
        # TODO: handle paging properly
        return all_local if local_mode?
        response = self.get('/iiif_manifests.json')
        raise FetchError, "Error fetching preserved_files: #{response.code} - #{response.message}" unless response.code == 200
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

      def self.model_name
        'iiif_manifests'
      end

      def self.deposit_new(deposit_items)
        return deposit_new_local(deposit_items) if local_mode?
        response = self.post("iiif_manifests/deposit.json", {query: {deposit_items: deposit_items}})
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
        response = self.post("iiif_manifests/#{CGI.escape manifest}/deposit.json", {query: {deposit_items: deposit_items}})
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
      
      def self.deposit_new_local(deposit_items)
        local_manifest = Trifle::IIIFManifest.new(title: "New manifest #{DateTime.now.strftime('%F %R')}")
        local_manifest.default_container_location!
        local_manifest.save
        
        job = Trifle::DepositJob.new(resource: local_manifest, deposit_items: deposit_items)
        job.queue_job
        {
          resource: self.from_json(local_manifest.as_json),
          status: 'ok',
          message: nil
        }
      end

    end
  end
end

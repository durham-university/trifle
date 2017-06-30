module Trifle
  class PublishIIIFActor < Trifle::BaseActor
    include DurhamRails::Actors::SFTPUploader
    include DurhamRails::Actors::FileCopier
    include Trifle::PackageUpload

    def initialize(model_object, user=nil, attributes={})
      super(model_object, user, attributes)
    end
    
    # target_id should be ark for manifests, and fedora id for collections
    def remove_remote_package(target_id, target_type, connection_params=nil, remote_path=nil)
      log!("Removing published iiif of #{target_type} #{target_id}")
      connection_params ||= Trifle.config['image_server_config'].symbolize_keys.except(:root, :iiif_root, :images_root)
      # TODO: remove_remote_package not implemented for local copy 
      raise 'remove_remote_package not implemented for local copy' if connection_params[:local_copy].to_s == 'true'
      case target_type.to_sym
      when :manifest
        remote_path ||= File.join("#{Trifle.config['image_server_config']['iiif_root']}", "#{treeify_id(target_id)}")
        sftp_rm_rf(remote_path, connection_params)
      when :collection
        remote_path ||= File.join("#{Trifle.config['image_server_config']['iiif_root']}", "collection/#{target_id}")
        sftp_rm_rf(remote_path, connection_params)
      end
    end
    
    def mark_clean
      if @model_object.respond_to?(:set_clean)
        log!("Marking manifest clean")
        @model_object.set_clean
        @model_object.save
      end
    end
    
    def upload_package(package=nil, connection_params=nil, remote_path=nil)
      super(package || iiif_package, connection_params, remote_path) do
        mark_clean
      end
    end
    
    def write_package(root_dir, package=nil)
      super(root_dir, package || iiif_package) do
        mark_clean
      end
    end
    
    def default_connection_params
      Trifle.config['image_server_config'].symbolize_keys.except(:root, :iiif_root, :images_root)
    end
    
    def default_remote_path
      Trifle.config['image_server_config'].symbolize_keys[:iiif_root]
    end
    
    def default_package_label
      "iiif of #{model_object.title} (#{model_object.id})"
    end

    def iiif_package(target=nil)
      Enumerator.new do |yielder|
        iiif_package_unstatified(target).each do |file|
          yielder << statify_file(file)
        end
      end
    end
    
    def iiif_package_unstatified(target=nil)
      opts = {iiif_version: '2.0'}
      target ||= model_object
      Enumerator.new do |yielder|
        case target
        when Trifle::IIIFManifest
          prefix = treeify_id
          yielder << FileEntry.new("#{prefix}/manifest", target.to_iiif(opts) )
          target.iiif_sequences(opts).each do |seq|
            raise "Sequence label contains invalid characters #{seq.label}" unless /^[a-zA-Z0-9_-]+$/ =~ seq.label
            yielder << FileEntry.new("#{prefix}/sequence/#{seq.label}", seq )
          end
          target.traverse_ranges.each do |range|
            raise "Range id contains invalid characters #{range.id}" unless /^[a-zA-Z0-9_-]+$/ =~ range.id
            yielder << FileEntry.new("#{prefix}/range/#{range.id}", range.to_iiif(opts) )
          end
          target.images.each do |image|
            raise "Image id contains invalid characters #{image.id}" unless /^[a-zA-Z0-9_-]+$/ =~ image.id
            yielder << FileEntry.new("#{prefix}/canvas/#{image.id}", image.to_iiif(opts) )
            yielder << FileEntry.new("#{prefix}/annotation/canvas_#{image.id}", image.iiif_annotation(opts) )

            image.annotation_lists.each do |list|
              raise "Annotation list id contains invalid characters #{list.id}" unless /^[a-zA-Z0-9_-]+$/ =~ list.id
              yielder << FileEntry.new("#{prefix}/list/#{list.id}", list.to_iiif(opts) )
              
              list.annotations.each do |annotation|
                raise "Annotation id contains invalid characters #{annotation.id}" unless /^[a-zA-Z0-9_-]+$/ =~ annotation.id
                yielder << FileEntry.new("#{prefix}/annotation/#{annotation.id}", annotation.to_iiif(opts) )
              end
            end
          end
          unless attributes[:skip_parent]
            target.parents.select do |o| o.is_a?(Trifle::IIIFCollection) end .each do |collection|
              raise "Collection has no local_ark" unless collection.local_ark.present?
              yielder << FileEntry.new("collection/#{collection.local_ark.split('/')[1..2].join('/')}", collection.to_iiif(opts))
            end
          end
        when Trifle::IIIFCollection
          raise "Target has no local_ark" unless target.local_ark.present?
          yielder << FileEntry.new("collection/#{target.local_ark.split('/')[1..2].join('/')}", target.to_iiif(opts))
          unless attributes[:skip_parent]
            parent = target.parent
            if parent
              raise "Parent has no local_ark" unless parent.local_ark.present?
              yielder << FileEntry.new("collection/#{parent.local_ark.split('/')[1..2].join('/')}", parent.to_iiif(opts))
            else
              yielder << FileEntry.new("collection/index", Trifle::IIIFCollection.index_collection_iiif(opts))
            end
          end
        end
      end
    end
    
    private
    
      def statify_file(file_entry)
        FileEntry.new(file_entry.path, convert_ids(file_entry.content).to_json(pretty: true))
      end
      
      def rails_manifest_prefix
        # This'll be /trifle/iiif/manifest/
        @rails_manifest_prefix ||= Trifle::Engine.routes.url_helpers.iiif_manifest_iiif_url(model_object, host: Trifle.iiif_host) \
                            .split("/#{model_object.id}/",2).first+"/"
      end
      
      def rails_collection_prefix
        # This'll be /trifle/iiif/collection/
        @rails_collection_prefix ||= Trifle::Engine.routes.url_helpers.iiif_collection_iiif_url('', host: Trifle.iiif_host)
      end
      
      def ark_naan
        # NOTE: We are assuming here that all objects referenced in the iiif have
        # the same NAAN as the main model_object.
        model_object.ark_naan
      end
      
      def to_ark(target)
        if target.is_a?(String)
          if target.start_with?("ark:")
            target
          else
            "ark:/#{ark_naan}/#{target}"
          end
        else
          target.local_ark
        end
      end
      
      def treeify_id(target=nil)
        target ||= model_object
        ark = to_ark(target)
        @treeify_id = begin
          (naan,id) = ark[5..-1].split('/')
          [naan, *id.match(/(..)(..)(..)/)[1..-1], id].join('/')
        end
      end
      
      def treeified_prefix(target=nil)
        Trifle.config['published_iiif_url'] + treeify_id(target) + '/'
      end
    
      def convert_id(id)
        if id == rails_collection_prefix[0..-2]
          # this is the index collection, prefix is /trifle/iiif/collection without a trailing slash
          "#{Trifle.config['published_iiif_url']}collection/index"
        elsif id.start_with?(rails_manifest_prefix)
          # rails_manifest_preix will have manifest_id in it, replace it with treeified prefix
          (man_id, rest) = id[(rails_manifest_prefix.length)..-1].split('/',2)
          treeified_prefix(man_id) + rest
        elsif id.start_with?(rails_collection_prefix)
          "#{Trifle.config['published_iiif_url']}collection/#{ark_naan}/#{id[(rails_collection_prefix.length)..-1]}"
        else
          id
        end
      end
    
      def convert_ids(iiif)
        iiif['@id'] = convert_id(iiif['@id']) if iiif['@id'].present?
        iiif['on'] = convert_id(iiif['on']) if iiif['on'].present? && iiif['on'].is_a?(String)
        iiif['within'] = convert_id(iiif['within']) if iiif['within'].present? && iiif['within'].is_a?(String)
        if iiif['@type'] == 'sc:Range'
          iiif['canvases'].map! do |id| convert_id(id) end if iiif['canvases']
          iiif['ranges'].map! do |id| convert_id(id) end if iiif['ranges']
        end
        iiif.each do |key,value|
          if value.is_a?(Array)
            value.each do |avalue|
              convert_ids(avalue) if avalue.is_a?(IIIF::HashBehaviours)
            end
          elsif value.is_a?(IIIF::HashBehaviours)
            convert_ids(value)
          end
        end
      end
        
    class FileEntry < Trifle::PackageUpload::FileEntry ; end
  end
end

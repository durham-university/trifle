module Trifle
  class StaticIIIFActor < Trifle::BaseActor
    include DurhamRails::Actors::SFTPUploader

    def initialize(model_object, user=nil, attributes={})
      super(model_object, user, attributes)
    end
    
    # target_id should be ark for manifests, and fedora id for collections
    def remove_remote_package(target_id, target_type, connection_params=nil, remote_path=nil)
      log!("Removing static iiif of #{target_type} #{target_id}")
      connection_params ||= Trifle.config['image_server_ssh'].symbolize_keys.except(:root, :iiif_root, :images_root)
      case target_type.to_sym
      when :manifest
        remote_path ||= File.join("#{Trifle.config['image_server_ssh']['iiif_root']}", "#{treeify_id(target_id)}")
        sftp_rm_rf(remote_path, connection_params)
      when :collection
        remote_path ||= File.join("#{Trifle.config['image_server_ssh']['iiif_root']}", "collection/#{target_id}")
        sftp_rm_rf(remote_path, connection_params)
      end
    end
    
    def mark_clean
      if @model_object.respond_to?(:set_clean)
        @model_object.set_clean
        @model_object.save
      end
    end

    def upload_package(package=nil, connection_params=nil, remote_path=nil)
      log!("Uploading static iiif")
      package ||= iiif_package
      connection_params ||= Trifle.config['image_server_ssh'].symbolize_keys.except(:root, :iiif_root, :images_root)
      remote_path ||= "#{Trifle.config['image_server_ssh']['iiif_root']}"
      package.each do |file_entry|
        full_path = File.join(remote_path,file_entry.path)
        log!("Sending file #{full_path}")
        return false unless send_file(StringIO.new(file_entry.content), full_path, connection_params)
      end
      mark_clean
      true
    end
    
    def write_package(root_dir, package=nil)
      log!("Writing static iiif")
      package ||= iiif_package
      package.each do |file_entry|
        full_path = File.join(root_dir, file_entry.path)
        log!("Writing file #{full_path}")
        dir_name = File.dirname(full_path)
        FileUtils.mkdir_p(dir_name)
        File.open(full_path,'wb') do |file|
          file.write(file_entry.content)
        end
      end
      mark_clean
      true
    end
              
    def iiif_package(target=nil)
      Enumerator.new do |yielder|
        iiif_package_unstatified(target).each do |file|
          yielder << statify_file(file)
        end
      end
    end
    
    def iiif_package_unstatified(target=nil)
      target ||= model_object
      Enumerator.new do |yielder|
        case target
        when Trifle::IIIFManifest
          prefix = treeify_id
          yielder << FileEntry.new("#{prefix}/manifest", target.to_iiif )
          target.iiif_sequences.each do |seq|
            raise "Sequence label contains invalid characters #{seq.label}" unless /^[a-zA-Z0-9_-]+$/ =~ seq.label
            yielder << FileEntry.new("#{prefix}/sequence/#{seq.label}", seq )
          end
          target.traverse_ranges.each do |range|
            raise "Range id contains invalid characters #{range.id}" unless /^[a-zA-Z0-9_-]+$/ =~ range.id
            yielder << FileEntry.new("#{prefix}/range/#{range.id}", range.to_iiif )
          end
          target.images.each do |image|
            raise "Image id contains invalid characters #{image.id}" unless /^[a-zA-Z0-9_-]+$/ =~ image.id
            yielder << FileEntry.new("#{prefix}/canvas/#{image.id}", image.to_iiif )
            yielder << FileEntry.new("#{prefix}/annotation/canvas_#{image.id}", image.iiif_annotation )

            image.annotation_lists.each do |list|
              raise "Annotation list id contains invalid characters #{list.id}" unless /^[a-zA-Z0-9_-]+$/ =~ list.id
              yielder << FileEntry.new("#{prefix}/list/#{list.id}", list.to_iiif )
              
              list.annotations.each do |annotation|
                raise "Annotation id contains invalid characters #{annotation.id}" unless /^[a-zA-Z0-9_-]+$/ =~ annotation.id
                yielder << FileEntry.new("#{prefix}/annotation/#{annotation.id}", annotation.to_iiif )
              end
            end
          end
          target.parents.select do |o| o.is_a?(Trifle::IIIFCollection) end .each do |collection|
            yielder << FileEntry.new("collection/#{collection.id}", collection.to_iiif)
          end
        when Trifle::IIIFCollection
          yielder << FileEntry.new("collection/#{target.id}", target.to_iiif)
          parent = target.parent
          yielder << FileEntry.new("collection/#{parent.id}", parent.to_iiif) if parent
        end
      end
    end
    
    private
    
      def statify_file(file_entry)
        FileEntry.new(file_entry.path, convert_ids(file_entry.content).to_json(pretty: true))
      end
      
      def rails_manifest_prefix
        # This'll be /trifle/iiif/manifest/:manifest_id/
        @rails_manifest_prefix ||= Trifle::Engine.routes.url_helpers.iiif_manifest_iiif_url(model_object, host: Trifle.iiif_host) \
                            .split("/#{model_object.id}/",2).first+"/#{model_object.id}/"
      end
      
      def rails_collection_prefix
        # This'll be /trifle/iiif/collection/
        @rails_collection_prefix ||= Trifle::Engine.routes.url_helpers.iiif_collection_iiif_url('', host: Trifle.iiif_host)
      end
      
      def treeify_id(target=nil)
        target ||= model_object
        ark = target.is_a?(String) ? target : target.local_ark
        @treeify_id = begin
          (naan,id) = ark[5..-1].split('/')
          [naan, *id.match(/(..)(..)(..)/)[1..-1], id].join('/')
        end
      end
      
      def treeified_prefix
        @treeified_prefix ||= Trifle.config['static_iiif_url'] + treeify_id + '/'
      end
    
      def convert_id(id)
        if id.start_with?(rails_manifest_prefix)
          treeified_prefix + id[(rails_manifest_prefix.length)..-1]
        elsif id.start_with?(rails_collection_prefix)
          Trifle.config['static_iiif_url'] + "collection/" + id[(rails_collection_prefix.length)..-1]
        else
          id
        end
      end
    
      def convert_ids(iiif)
        iiif['@id'] = convert_id(iiif['@id']) if iiif['@id'].present?
        iiif['on'] = convert_id(iiif['on']) if iiif['on'].present? && iiif['on'].is_a?(String)
        iiif['within'] = convert_id(iiif['within']) if iiif['within'].present? && iiif['within'].is_a?(String)
        if iiif['@type'] == 'sc:Range' && iiif['canvases']
          iiif['canvases'].map! do |id| convert_id(id) end
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
        
    class FileEntry
      attr_accessor :path, :content
      def initialize(path,content=nil)
        self.path = path
        self.content = content
      end
    end
  end
end
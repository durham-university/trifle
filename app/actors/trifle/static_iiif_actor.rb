module Trifle
  class StaticIIIFActor < Trifle::BaseActor
    include DurhamRails::Actors::SFTPUploader

    def initialize(model_object, user=nil, attributes={})
      super(model_object, user, attributes)
    end

    def upload_package(package=nil, connection_params=nil, remote_path=nil)
      package ||= iiif_package
      connection_params ||= Trifle.config['image_server_ssh'].symbolize_keys.except(:root, :iiif_root)
      remote_path ||= "#{Trifle.config['image_server_ssh']['iiif_root']}"
      package.each do |file_entry|
        full_path = File.join(remote_path,file_entry.path)
        log!("Sending file #{full_path}")
        send_file(StringIO.new(file_entry.content), full_path, connection_params)
      end
    end
    
    def write_package(root_dir, package=nil)
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
    end
          
    def iiif_package
      Enumerator.new do |yielder|
        iiif_package_unstatified.each do |file|
          yielder << statify_file(file)
        end
      end
    end
    
    def iiif_package_unstatified
      Enumerator.new do |yielder|
        prefix = treeify_id
        yielder << FileEntry.new("#{prefix}/manifest", model_object.to_iiif )
        model_object.iiif_sequences.each do |seq|
          raise "Sequence label contains invalid characters #{seq.label}" unless /^[a-zA-Z0-9_-]+$/ =~ seq.label
          yielder << FileEntry.new("#{prefix}/sequence/#{seq.label}", seq )
        end
        model_object.traverse_ranges.each do |range|
          raise "Range id contains invalid characters #{range.id}" unless /^[a-zA-Z0-9_-]+$/ =~ range.id
          yielder << FileEntry.new("#{prefix}/range/#{range.id}", range.to_iiif )
        end
        model_object.images.each do |image|
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
      end
    end
    
    private
    
      def statify_file(file_entry)
        FileEntry.new(file_entry.path, convert_ids(file_entry.content).to_json(pretty: true))
      end
      
      def rails_id_prefix
        # This'll be /trifle/iiif/manifest/:manifest_id/
        @rails_id_prefix ||= Trifle::Engine.routes.url_helpers.iiif_manifest_iiif_url(model_object, host: Trifle.iiif_host) \
                            .split("/#{model_object.id}/",2).first+"/#{model_object.id}/"
      end
      
      def treeify_id
        @treeify_id = begin
          (naan,id) = model_object.local_ark[5..-1].split('/')
          [naan, *id.match(/(..)(..)(..)/)[1..-1], id].join('/')
        end
      end
      
      def treeified_prefix
        @treeified_prefix ||= Trifle.config['static_iiif_url'] + treeify_id + '/'
      end
    
      def convert_id(id)
        return id unless id.start_with?(rails_id_prefix)
        treeified_prefix + id[(rails_id_prefix.length)..-1]
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

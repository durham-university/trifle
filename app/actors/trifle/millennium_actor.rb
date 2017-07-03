module Trifle
  class MillenniumActor < Trifle::BaseActor
    include DurhamRails::Actors::SFTPUploader
    include DurhamRails::Actors::FileCopier
    include Trifle::PackageUpload

    def initialize(model_object, user=nil, attributes={})
      super(model_object, user, attributes)
    end
    
    def upload_package(package=nil, connection_params=nil, remote_path=nil)
      super(package || millennium_package, connection_params, remote_path)
    end
    
    def write_package(root_dir, package=nil)
      super(root_dir, package || millennium_package)
    end
    
    def default_package_label
      "Millennium package for #{model_object.title} (#{model_object.id})"
    end
    
    def millennium_package(target=nil, format="xml")
      target ||= model_object
      Enumerator.new do |yielder|
        target.to_millennium_all.each do |mid,fields|
          existing_fields = preserved_millennium_fields(mid)
          
          r = MARC::Record.new()
          existing_fields.each do |f| r.append(f) end
          fields.each do |f| r.append(f) end
            
          content = case format
          when "xml"
            writer = StringIO.new
            xml_writer = MARC::XMLWriter.new(writer)
            xml_writer.write(r)
            xml_writer.close
            writer.string
          when "marc"
            r.to_s
          else
            raise "Invalid millennium record format #{format}"
          end
          yielder << Trifle::PackageUpload::FileEntry.new(mid, content)
        end
      end
    end
    
    def preserved_millennium_fields(mid)
      r = DurhamRails::LibrarySystems::Millennium.connection.record(mid).marc_record
      fields_533 = r.fields.select do |f| f.tag == '533' end
      fields_856 = r.fields.select do |f| f.tag == '856' end
        
      fields_533.select! do |f| f['a'] != 'Digital image' end
      
      n2t_server = Trifle.config['n2t_server'] || 'https://n2t.durham.ac.uk'
      n2t_matcher = /^#{n2t_server}\/ark:\/[0-9]+\/t[0-9][0-9a-z]+\.html$/
      fields_856.select! do |f| !n2t_matcher.match(f['u']) end
        
      fields_533 + fields_856
    end
    
    protected
    
    def default_connection_params
      Trifle.config['millennium_linking_config'].symbolize_keys.except(:root)
    end
    
    def default_remote_path
      Trifle.config['millennium_linking_config'].symbolize_keys[:root]
    end
    
  end
end

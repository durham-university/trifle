module Trifle
  class MillenniumActor < Trifle::BaseActor
    include DurhamRails::Actors::SFTPUploader
    include DurhamRails::Actors::FileCopier
    include Trifle::PackageUpload

    def initialize(model_object, user=nil, attributes={})
      super(model_object, user, attributes)
    end

    # Use this to upload all millennium linked objects. 
    # a = Trifle::MillenniumActor.new(nil)
    # a.log.to_stdout! # If needed
    # a.upload_everything
    def upload_everything
      rs = ActiveFedora::Base.where("source_record_ssim:millennium*").from_solr!
      re = /^millennium:([^#]+)(#.*)?$/
      index = {}
      rs.each do |o|
        m = re.match(o.source_record)
        next unless m
        next if index.key?(m[1])
        index[m[1]] = o
      end
      log!("Found #{index.count} unique Millennium references")

      index.each do |millennium_id, o|
        @model_object = o
        upload_package
      end
      nil
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
#          existing_fields = existing_millennium_fields(mid)
#          existing_fields = remove_old_injected_fields(existing_fields)
#          Trifle::IIIFManifest.reassign_marc_field_links(existing_fields, fields)
          
          r = MARC::Record.new()
#          pick_relevant_fields(existing_fields).each do |f| r.append(f) end
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
    
    def existing_millennium_fields(mid)
      DurhamRails::LibrarySystems::Millennium.connection.record(mid).marc_record.fields.to_a
    end
    
    def remove_old_injected_fields(existing_fields)
      n2t_server = Trifle.config['n2t_server'] || 'https://n2t.durham.ac.uk'
      n2t_matcher = /^#{n2t_server}\/ark:\/[0-9]+\/t[0-9][0-9a-z]+\.html$/
      
      injected_subfields = []
      existing_fields.select do |f|
        if f.tag == '856' && f['x'] == 'Injected by Trifle'
          sub_index = subfield_index(f)
          injected_subfields << sub_index if sub_index.present?
        end
      end
      
      existing_fields.select do |f|
        case f.tag
        when '533'
          sub_index = subfield_index(f)
          sub_index.nil? || !injected_subfields.include?(sub_index)
        when '856'
          f['x'] != 'Injected by Trifle'
        else
          true
        end
      end
    end
    
    def pick_relevant_fields(fields)
      fields.select do |f| f.tag == '533' || f.tag == '856' end
    end
    
    protected
    
    def subfield_index(f)
      return nil unless f.is_a?(MARC::DataField) && f['8'].present?
      re = /^([^\d]*)(\d+)(.*)$/
      m = re.match(f['8'])
      m.try(:[],2)
    end
    
    def default_connection_params
      Trifle.config['millennium_linking_config'].symbolize_keys.except(:root)
    end
    
    def default_remote_path
      Trifle.config['millennium_linking_config'].symbolize_keys[:root]
    end
    
  end
end

module Trifle
  module SourceRecord
    extend ActiveSupport::Concern
    
    included do
      property :source_record, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#source_record')
    end
    
    def source_type
      ind = source_record.index(':')
      return nil if ind.nil? || ind==0
      source_record[0..(ind-1)]
    end
    
    def source_identifier
      ind = source_record.index(':')
      return source_record if ind.nil?
      return source_record[1..-1] if ind==0
      source_record[(ind+1)..-1]
    end
    
    def refresh_from_source
      raise 'Source type not set' unless source_type.present?
      type_method = :"refresh_from_#{source_type.to_s.underscore}_source"
      raise 'Unknown source type' unless self.respond_to?(type_method)
      self.send(type_method)
    end
    
    def refresh_from_millenium_source
      raise 'TODO'
    end
    
    def refresh_from_adlib_source
      raise 'TODO'
    end
    
    def refresh_from_schmit_source
      schmit_id, item_id = source_identifier.split('#',2)
      raise("Source identifier doesn't contain an item_id: #{source_identifier}") unless item_id.present?
      
      record = Schmit::API::Catalogue.try_find(schmit_id) || raise("Couldn't find Schmit record #{schmit_id}")
      
      xml_record = record.xml_record || raise("Couldn't get xml_record for #{schmit_id}")
      item = xml_record.sub_item(item_id) || raise("Couldn't find sub item #{item_id} for #{schmit_id}")
      
      self.title = item.title_path if item.title_path.present?
      self.date_published = item.date if item.date.present?
      self.description = item.scopecontent if item.scopecontent.present?
      true
    end
    
  end
end
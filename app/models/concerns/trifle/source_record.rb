module Trifle
  module SourceRecord
    extend ActiveSupport::Concern
    
    included do
      property :source_record, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#source_record') do |index|
        index.as :symbol
      end
    end
    
    def source_type
      return nil unless source_record.present?
      ind = source_record.index(':')
      return nil if ind.nil? || ind==0
      source_record[0..(ind-1)]
    end
    
    def source_identifier
      return nil unless source_record.present?
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
      item = DurhamRails::LibrarySystems::Adlib.connection.record(source_identifier)
      raise("Couldn't find Adlib record #{source_identifier}") unless item && item.exists?
      
      self.title = item.title if item.title.present?
      date = item.production_date || item.period
      self.date_published = date if date.present?
      self.description = item.description if item.description.present?
      true
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
    
    module ClassMethods
      def find_from_source(source,prefix=true)
        solr_field = Solrizer.solr_name(:source_record,*self.reflect_on_property(:source_record).behaviors)
        # one escape for ruby, one for replacement patterns, one for _query_ string and one for v= string
        escaped = source.gsub("\\","\\\\\\\\\\\\\\\\").gsub("\"","\\\\\\\\\\\"")
        if prefix
          self.all.where("_query_:\"{!prefix f=#{solr_field} v=\\\"#{escaped}\\\"}\"")
        else
          self.all.where("_query_:\"{!raw f=#{solr_field} v=\\\"#{escaped}\\\"}\"")
        end
      end
    end
    
  end
end
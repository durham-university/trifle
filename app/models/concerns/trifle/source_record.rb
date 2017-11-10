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
    
    def source_url
      if source_record.try(:start_with?,'schmit:')
        Schmit::API::Catalogue.record_url(source_record.split(':',2).last)
      else
        nil
      end
    end
    
    def public_source_link
      if source_record.try(:start_with?,'schmit:')
        return nil unless Schmit::API.config['schmit_xtf_base_url'].present?
        split = source_record.split('/')[1..-1].join('_').split('#')
        split[0] += '.xml'
        url = Schmit::API.config['schmit_xtf_base_url']+(split.join('#'))
        {'@id' => url, 'label' => 'Catalogue record'}
      elsif source_record.try(:start_with?,'millennium:')
        return nil unless Trifle.config['millennium_base_url'].present?
        millennium_id = source_record.split(':',2)[1].split('#')[0]
        url = Trifle.config['millennium_base_url']+(millennium_id)
        {'@id' => url, 'label' => 'Catalogue record'}
      elsif source_record.try(:start_with?,'adlib:')
        return nil unless Trifle.config['adlib_base_url'].present?
        adlib_id = source_record.split(':',2)[1].split('#')[0]
        url = Trifle.config['adlib_base_url']+(adlib_id)
        {'@id' => url, 'label' => 'Catalogue record'}
      else
        nil
      end
    end
    
    def refresh_from_source(cache=nil)
      raise 'Source type not set' unless source_type.present?
      type_method = :"refresh_from_#{source_type.to_s.underscore}_source"
      raise 'Unknown source type' unless self.respond_to?(type_method)
      self.send(type_method, cache)
    end
    
    def refresh_from_millenium_source(cache=nil)
      raise 'TODO'
    end
    
    def refresh_from_adlib_source(cache=nil)
      cache ||= {} # forcing a non-persistent empty cache simplifies code
      adlib_identifier = source_identifier
      cache[adlib_identifier] ||= DurhamRails::LibrarySystems::Adlib.connection.record(adlib_identifier)
      item = cache[adlib_identifier]
      raise("Couldn't find Adlib record #{adlib_identifier}") unless item && item.exists?
      
#      if item.title.present?
#        self.title = item.title 
#        self.title += self.subtitle if self.subtitle.present?
#      end
      date = item.production_date || item.period
      self.date_published = date if date.present?
      description = item.web_label || item.description
      self.description = description if description.present?
      true
    end
    
    def refresh_from_schmit_source(cache=nil)
      cache ||= {} # forcing a non-persistent empty cache simplifies code
      schmit_id, item_id = source_identifier.split('#',2)
      
      cache[schmit_id] ||= Schmit::API::Catalogue.try_find(schmit_id)
      record = cache[schmit_id] || raise("Couldn't find Schmit record #{schmit_id}")
      
      xml_record = record.xml_record || raise("Couldn't get xml_record for #{schmit_id}")
      item = item_id.nil? ? xml_record.root_item : (xml_record.sub_item(item_id) || raise("Couldn't find sub item #{item_id} for #{schmit_id}"))
      
#      if item.title_path.present?
#        self.title = item.title_path.gsub(/(?i)^(catalogue of (the)?\s*)/,'')
#        self.title += self.subtitle if self.subtitle.present?
#      end      
      
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
          self.all.from_solr!.where("_query_:\"{!prefix f=#{solr_field} v=\\\"#{escaped}\\\"}\"")
        else
          self.all.from_solr!.where("_query_:\"{!raw f=#{solr_field} v=\\\"#{escaped}\\\"}\"")
        end
      end
    end
    
  end
end
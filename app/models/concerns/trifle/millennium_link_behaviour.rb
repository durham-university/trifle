module Trifle
  module MillenniumLinkBehaviour
    extend ActiveSupport::Concern
    
    def to_millennium
      # NOTE: Millennium actor has code which recognises and removes fields
      # created here. Adding new fields may require modifying that code as well.

      # NOTE: Publishing happens automatically at initial deposit. It is assumed that
      # the fields included in Millennium will only change very infrequently if at all
      # and a new linking job is manually triggered if they do. If any fields are included
      # here which might change more frequently, then it might be worthwhile to do the
      # Millennium export automatically at any modification (or publishing).
      
      return nil unless self.source_record.try(:start_with?,'millennium:')
      raise "Record doesn't have an ark" unless self.local_ark.present?
      
      n2t_url = "#{Trifle.config.fetch('n2t_server','https://n2t.durham.ac.uk')}/#{self.local_ark}.html"
      millennium_id, holding_id = self.source_record[('millennium:'.length)..-1].split('#',2)
      
      shelf_mark = if holding_id.present?
        r = DurhamRails::LibrarySystems::Millennium.connection.record(millennium_id)
        if r.present?
          h = r.holdings.find do |h| h.holding_id == holding_id end
          h.try(:call_no)
        end
      else
        nil
      end
      
      {
        millennium_id => [
#          MARC::DataField.new('533', nil, nil, *(
#            [['8', "1\\c"]] +
#            (shelf_mark.present? ? [['3', shelf_mark]] : []) +
#            [['a', 'Digital image'], ['c', 'Durham University']] +
#            (self.try(:digitisation_note).present? ? [['n', self.try(:digitisation_note)]] : []) +
#            [['5', 'UkDhU']]
#          )),
          MARC::DataField.new('856', '4', '1', *(
#            [['8',"1\\c"]] +
            (shelf_mark.present? ? [['3', shelf_mark]] : []) +
            [['u', n2t_url], ['y', 'Online version']] +
            (self.try(:digitisation_note).present? ? [['z', self.digitisation_note]] : []) +
            [['x', 'Injected by Trifle']]
          )),
        ]
      }
    end
    
    def to_millennium_all
      return nil unless self.source_record.try(:start_with?,'millennium:')
      millennium_source, _ = self.source_record.split('#')
      
      ms = Trifle::IIIFManifest.find_from_source(millennium_source,true).to_a
      cs = Trifle::IIIFCollection.find_from_source(millennium_source,true).to_a
      is = Trifle::IIIFImage.find_from_source(millennium_source,true).to_a
      
      (ms + cs + is).reduce({}) do |all_records, m|
        (m.to_millennium || {}).each do |k,vs|
          all_records[k] ||= []
          self.class.reassign_marc_field_links(all_records[k], vs)
          all_records[k].push(*vs)
        end
        all_records
      end
    end
    
    module ClassMethods
      def reassign_marc_field_links(existing_fields, new_fields)
        # Marc subfield 8 links several data fields together. When combining
        # fields from several sources, they may have clashes in the link ids
        # the use. This reassigns the link ids in new_fields so that they
        # don't clash with anything in existing_fields.

        re = /^([^\d]*)(\d+)(.*)$/
        
        used_links = {}
        existing_fields.each do |f|
          next unless f.is_a?(MARC::DataField)
          f.each do |s|
            next unless s.code == '8'
            m = re.match(s.value)
            next unless m
            used_links[m[2]] = true
          end
        end

        new_map = {}
        last_used = used_links.keys.map(&:to_i).max || 0        
        
        new_fields.each do |f|
          next unless f.is_a?(MARC::DataField)
          f.each do |s|
            next unless s.code == '8'
            m = re.match(s.value)
            next unless m
            link_id = m[2]
            
            link_id = new_map[link_id] || begin
              last_used += 1
              new_map[link_id] = last_used.to_s
            end
            
            s.value = "#{m[1]}#{link_id}#{m[3]}"
          end
        end
        new_fields
      end
    end
    
  end
end
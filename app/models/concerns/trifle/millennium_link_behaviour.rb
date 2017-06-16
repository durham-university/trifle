module Trifle
  module MillenniumLinkBehaviour
    extend ActiveSupport::Concern
    
    def to_millennium
      return nil unless self.source_record.try(:start_with?,'millennium:')
      raise "Record doesn't have an ark" unless self.local_ark.present?
      
      # There is a marc gem which could be used for this but it offers very little benefit.
      
      n2t_url = "#{Trifle.config.fetch('n2t_server','https://n2t.durham.ac.uk')}/#{self.local_ark}.html"
      millennium_id, holdind_id = self.source_record[('millennium:'.length)..-1].split('#',2)
      {
        millennium_id => [
          "n 533 |aDigital image#{ self.try(:digitisation_note).present? ? "|n#{digitisation_note}" : ""}|5UkDhU",
          "y 856 4 1 |zOnline version|u#{n2t_url}"
        ]
      }
    end
    
    def to_millennium_all
      return nil unless self.source_record.try(:start_with?,'millennium:')
      millennium_source, _ = self.source_record.split('#')
      
      ms = Trifle::IIIFManifest.find_from_source(millennium_source,true).to_a
      cs = Trifle::IIIFCollection.find_from_source(millennium_source,true).to_a
      
      (ms + cs).reduce({}) do |all_records, m|
        (m.to_millennium || {}).each do |k,vs|
          (all_records[k] ||= []).push(*vs)
        end
        all_records
      end
    end
    
  end
end
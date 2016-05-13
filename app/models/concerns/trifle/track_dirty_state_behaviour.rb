module Trifle
  module TrackDirtyStateBehaviour
    extend ActiveSupport::Concern
    
    included do
      property :dirty_state, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/trifle#dirty_state') do |index|
        index.as :symbol
      end
      
      def dirty_state=(*args)
        super(*args)
        # ensure dirty_state gets set, even if it already had the same value
        self.changed_attributes[:dirty_state] = self.dirty_state unless self.changed_attributes.has_key?(:dirty_state)
      end      
      
      before_save :save_set_dirty
    end
    
    def dirty?
      dirty_state == 'dirty'
    end
    
    def clean?
      !dirty?
    end
        
    def set_dirty
      self.dirty_state = 'dirty'
    end
    
    def set_clean
      self.dirty_state = 'clean'
    end
    
    module ClassMethods
      def all_dirty
        all.where("#{Solrizer.solr_name(:dirty_state,:symbol)}:\"dirty\"")
      end
    end
    
    private 
    
      def save_set_dirty
        # ActiveFedora will call save internally if members have been chaned.
        # This results in these callbacks being called twice, the second time
        # would always set_dirty. If changed_attributes has head and tail then
        # ignore this callback. It's unlikely that the user would set these manually
        # so this call is probably the second internal call.
        return if changed_attributes.has_key?(:head) && changed_attributes.has_key?(:tail)
        unless changed_attributes.has_key?(:dirty_state)
          set_dirty
        end
      end
    
  end
end
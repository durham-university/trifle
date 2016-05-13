module Trifle
  module TrackDirtyParentBehaviour
    extend ActiveSupport::Concern
    
    included do
      before_save :set_parents_dirty
      before_destroy :set_parents_dirty
    end
        
    def dirty_tracking_parents
      if self.respond_to?(:parents)
        self.parents
      else
        [self.parent].compact
      end .map do |p|
        case p
        when Trifle::TrackDirtyStateBehaviour
          p
        when Trifle::TrackDirtyParentBehaviour
          p.dirty_tracking_parents
        else
          nil
        end
      end .to_a.compact.flatten
    end
    
    private
    
      def set_parents_dirty(do_save=true)
        dirty_tracking_parents.each do |p|
          unless p.dirty?
            p.set_dirty
            p.save if do_save
          end
        end
      end
  end
end
module Trifle
  module UpdateRangesBehaviour
    extend ActiveSupport::Concern
    
    included do
      before_action :set_update_ranges_resource, only: [:update_ranges]
    end
    
    def update_ranges
      actor = Trifle::UpdateRangesActor.new(@resource, current_user)
      ranges_json = JSON.parse(request.body.read)['ranges']
      actor.update_ranges(ranges_json)
      if actor.log.errors?
        render json: {status: 'error'}.merge(actor.log.as_json)
      else
        render json: {status: 'ok'}
      end
    end
    
    private
    
      def set_update_ranges_resource
        set_resource
      end
    
  end
end
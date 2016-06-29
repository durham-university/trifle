module Trifle
  module AutoPublishResourceBehaviour
    extend ActiveSupport::Concern
    include PublishResourceBehaviour
        
    private
    
    def publish?
      true
    end
  end
end
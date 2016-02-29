module Trifle
  module AllowCorsBehaviour
    extend ActiveSupport::Concern
    
    # This concern should be the last one included so that the before_filter
    # comes last in the filter chain.
    
    included do
      before_filter :cors_preflight_check
      after_filter :cors_set_access_control_headers
    end
    
    def cors_dummy_page
      render text: ''
    end
    
    private 
      def set_cors_headers?
        false
      end
    
      def cors_allow_origin
        '*'
      end
      
      def cors_allow_methods
        'GET, OPTIONS'
      end
      
      def cors_allow_headers
        'Origin,Accept-Content-Type,X-Requested-With,X-CSRF-Token'
      end
    
      def cors_set_access_control_headers
        return unless set_cors_headers?
        headers['Access-Control-Allow-Origin'] = cors_allow_origin
        headers['Access-Control-Allow-Methods'] = cors_allow_methods
        headers['Access-Control-Allow-Headers'] = cors_allow_headers
        headers['Access-Control-Max-Age'] = '1728000'
      end
      
      def cors_preflight_check
        if request.method == :options && params['Access-Control-Request-Method']
          cors_set_access_control_headers
          render text: '', content_type: 'text/plain'
        end
      end
    
  end
end
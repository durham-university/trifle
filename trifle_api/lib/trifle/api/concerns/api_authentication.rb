module Trifle
  module API
    module APIAuthentication
      extend ActiveSupport::Concern
      
      included do
        class << self
          def authenticate_query(url,options)
            if Trifle::API.config['api_debug']
              options[:query] ||= {}
              options[:query].merge!(api_debug: 'true')
            end
          end

          def get(url,options={})
            authenticate_query(url,options)
            super
          end

          def post(url,options={})
            authenticate_query(url,options)
            super
          end
        end
      end      
    end
  end
end

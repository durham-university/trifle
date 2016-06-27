module Trifle
  class BackgroundJobContainersController < Trifle::ApplicationController
    include DurhamRails::BackgroundJobContainersControllerBehaviour
    
    def self.form_terms
      super - [:job_category]
    end
    
    protected
    
      def job_container_category
        :trifle
      end
    
  end
end
module Trifle
  module ApplicationHelper
    include DurhamRails::Helpers::BaseHelper
    
    def model_name
      return Trifle::IIIFCollection.model_name if controller.is_a?(Trifle::StaticPagesController)
      return super
    end

    def model_class
      return Trifle::IIIFCollection if controller.is_a?(Trifle::StaticPagesController)
      return super
    end
    
  end
end

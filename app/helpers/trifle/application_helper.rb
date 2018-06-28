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
    
    def render_ancestry_breadcrumbs(resource, active=true )
      if resource.try(:hidden_root?)
        index_path = engine_paths.polymorphic_path(resource.class)
        return safe_join ['<li>'.html_safe, link_to(resource.model_name.human.pluralize, index_path), '</li>'.html_safe]
      end
      super(resource, active)
    end
      
  end
end

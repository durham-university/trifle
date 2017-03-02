module Trifle
  module InheritLogo
    extend ActiveSupport::Concern
    
    def inherited_logo
      return logo if self.respond_to?(:logo) && logo.present?
      _parent = parent
      return _parent.inherited_logo if _parent.respond_to?(:inherited_logo)
      return _parent.logo if _parent.respond_to?(:logo)
      nil
    end
    
    def inherited_keeper
      return keeper if self.respond_to?(:keeper) && keeper.present?
      _parent = parent
      return _parent.inherited_keeper if _parent.respond_to?(:inherited_keeper)
      return _parent.keeper if _parent.respond_to?(:keeper)
      nil
    end
    
  end
end
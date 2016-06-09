module Trifle
  module ModelBase
    extend ActiveSupport::Concern

    def to_s
      title
    end

    def allow_destroy?
      return true
    end

    def as_json(*args)
      super(*args).except('head','tail')
    end
    
    # If the parent is known then use this to set it so it doesn't need to be 
    # fetched again.
    def has_parent!(parent)
      @parent ||= parent
      self
    end
  end
end

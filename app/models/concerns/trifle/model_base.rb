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
  end
end

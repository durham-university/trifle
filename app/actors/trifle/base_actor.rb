module Trifle
  class BaseActor
    attr_reader :model_object, :user, :attributes
    def initialize(model_object, user=nil, attributes={})
      @model_object = model_object
      @user = user
      @attributes = attributes.dup.with_indifferent_access
      @log = DurhamRails::Log.new
    end

    def log
      @log
    end

    delegate :log!, to: :log

  end
end

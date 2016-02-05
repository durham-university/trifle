module Trifle
  class IIIFManifestsController < Trifle::ApplicationController
    include DurhamRails::ModelControllerBase

    helper 'trifle/application'

    def self.presenter_terms
      super + [:identifier, :image_container_location]
    end

    def set_parent
    end
  end
end

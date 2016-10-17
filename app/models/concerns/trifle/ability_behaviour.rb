module Trifle
  module AbilityBehaviour
    extend ActiveSupport::Concern

    include CanCan::Ability

    def initialize(user)
      set_trifle_abilities(user)
    end

    def set_trifle_abilities(user)
      user ||= User.new
      if user.is_admin?
        can :manage, :all
      elsif user.is_editor?
      elsif user.is_registered?
      else
      end
      if user.is_api_user?
        can :show, [Trifle::IIIFCollection, Trifle::IIIFManifest, Trifle::IIIFImage]
        can :index, [Trifle::IIIFCollection, Trifle::IIIFManifest]
        can :destroy, [Trifle::IIIFManifest, Trifle::IIIFImage]
        can :index_all, [Trifle::IIIFCollection, Trifle::IIIFManifest]
        can :deposit_images, Trifle::IIIFManifest
        can :create_and_deposit_images, Trifle::IIIFManifest
        can :deposit_into, Trifle::IIIFCollection
      else
      end
    end
  end
end

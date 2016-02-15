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
      elsif user.is_registered?
      elsif user.is_api_user?
        can :deposit, Trifle::IIIFManifest
        can :create_and_deposit, Trifle::IIIFManifest
      else
      end
    end
  end
end

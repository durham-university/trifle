require "rails_helper"

RSpec.describe Trifle::StaticPagesController, type: :routing do
  routes { Trifle::Engine.routes }

  describe "root" do
    it "routes to #home" do
      expect(get: "/").to route_to("trifle/static_pages#home")
    end
  end

  describe "routing" do
    it "routes to #home" do
      expect(get: "/home").to route_to("trifle/static_pages#home")
    end
  end
end

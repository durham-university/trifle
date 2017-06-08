require "rails_helper"

RSpec.describe Trifle::ExportsController, type: :routing do
  describe "routing" do
    routes { Trifle::Engine.routes }

    it "routes to #show" do
      expect(:get => "/exports").to route_to("trifle/exports#show")
    end

    it "routes to #export_images" do
      expect(post: "/exports").to route_to("trifle/exports#export_images")
    end
  end
end

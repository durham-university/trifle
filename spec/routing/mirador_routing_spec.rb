require "rails_helper"

RSpec.describe Trifle::MiradorController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #show" do
    expect(get: "/mirador/1").to route_to("trifle/mirador#show", id: '1')
  end
  
  it "routes to #show with embed" do
    expect(get: "/mirador/1/embed").to route_to("trifle/mirador#show", id: '1', no_auto_load: 'true')
  end  
end

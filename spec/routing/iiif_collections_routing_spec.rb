require "rails_helper"

RSpec.describe Trifle::StaticPagesController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #index" do
    expect(get: "/collection").to route_to("trifle/iiif_collections#index")
  end
  it "routes to #show" do
    expect(get: "/collection/1").to route_to("trifle/iiif_collections#show", id: '1')
  end
  it "routes to #edit" do
    expect(get: "/collection/1/edit").to route_to("trifle/iiif_collections#edit", id: "1")
  end
  it "routes to #create" do
    expect(post: "/collection/1/collection").to route_to("trifle/iiif_collections#create", iiif_collection_id: "1")
  end
  it "routes to #new" do
    expect(get: "/collection/1/collection/new").to route_to("trifle/iiif_collections#new", iiif_collection_id: "1")
  end

  it "routes to #update via PUT" do
    expect(put: "/collection/1").to route_to("trifle/iiif_collections#update", id: "1")
  end

  it "routes to #update via PATCH" do
    expect(patch: "/collection/1").to route_to("trifle/iiif_collections#update", id: "1")
  end

  it "routes to #destroy" do
    expect(delete: "/collection/1").to route_to("trifle/iiif_collections#destroy", id: "1")
  end
  
  it "routes to #show_iiif" do
    expect(get: "/iiif/collection/1").to route_to("trifle/iiif_collections#show_iiif", id: "1")
  end
  
end

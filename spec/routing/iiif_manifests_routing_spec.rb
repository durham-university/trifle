require "rails_helper"

RSpec.describe Trifle::IIIFManifestsController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #index" do
    expect(get: "/iiif_manifests").to route_to("trifle/iiif_manifests#index")
  end
  it "routes to #show" do
    expect(get: "/iiif_manifests/1").to route_to("trifle/iiif_manifests#show", id: '1')
  end
  it "routes to #edit" do
    expect(get: "/iiif_manifests/1/edit").to route_to("trifle/iiif_manifests#edit", id: "1")
  end
  it "routes to #create" do
    expect(post: "/iiif_collections/1/iiif_manifests").to route_to("trifle/iiif_manifests#create", iiif_collection_id: "1")
  end
  it "routes to #new" do
    expect(get: "/iiif_collections/1/iiif_manifests/new").to route_to("trifle/iiif_manifests#new", iiif_collection_id: "1")
  end

  it "routes to #update via PUT" do
    expect(put: "/iiif_manifests/1").to route_to("trifle/iiif_manifests#update", id: "1")
  end

  it "routes to #update via PATCH" do
    expect(patch: "/iiif_manifests/1").to route_to("trifle/iiif_manifests#update", id: "1")
  end

  it "routes to #destroy" do
    expect(delete: "/iiif_manifests/1").to route_to("trifle/iiif_manifests#destroy", id: "1")
  end
  
  it "routes to #deposit_image via POST" do
    expect(post: "/iiif_manifests/1/deposit").to route_to("trifle/iiif_manifests#deposit_images", id: "1")
  end
  
  it "routes to #create_and_deposit_images via POST" do
    expect(post: "/iiif_collections/1/iiif_manifests/deposit").to route_to("trifle/iiif_manifests#create_and_deposit_images", iiif_collection_id: '1')
  end
  
  it "routes to #show_iiif" do
    expect(get: "/iiif_manifests/1/iiif").to route_to("trifle/iiif_manifests#show_iiif", id: "1")
  end
  
end

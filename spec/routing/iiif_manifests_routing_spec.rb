require "rails_helper"

RSpec.describe Trifle::StaticPagesController, type: :routing do
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
    expect(post: "/iiif_manifests").to route_to("trifle/iiif_manifests#create")
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
  
  it "routes to #create_and_deposit_image via POST" do
    expect(post: "/iiif_manifests/deposit").to route_to("trifle/iiif_manifests#create_and_deposit_images")
  end
  
end

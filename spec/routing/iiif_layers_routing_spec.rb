require "rails_helper"

RSpec.describe Trifle::IIIFLayersController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #show" do
    expect(get: "/manifest/2/layer/1").to route_to("trifle/iiif_layers#show", id: '1', iiif_manifest_id: '2')
  end
  it "routes to #edit" do
    expect(get: "/manifest/2/layer/1/edit").to route_to("trifle/iiif_layers#edit", id: "1", iiif_manifest_id: '2')
  end
  it "routes to #create" do
    expect(post: "/manifest/2/canvas/1/layer").to route_to("trifle/iiif_layers#create", iiif_image_id: "1", iiif_manifest_id: '2')
  end
  it "routes to #new" do
    expect(get: "/manifest/2/canvas/1/layer/new").to route_to("trifle/iiif_layers#new", iiif_image_id: "1", iiif_manifest_id: '2')
  end

  it "routes to #update via PUT" do
    expect(put: "/manifest/2/layer/1").to route_to("trifle/iiif_layers#update", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #update via PATCH" do
    expect(patch: "/manifest/2/layer/1").to route_to("trifle/iiif_layers#update", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #destroy" do
    expect(delete: "/manifest/2/layer/1").to route_to("trifle/iiif_layers#destroy", id: "1", iiif_manifest_id: '2')
  end
    
  it "routes to #show_iiif" do
    expect(get: "/iiif/manifest/2/layer/1").to route_to("trifle/iiif_layers#show_iiif", id: "1", iiif_manifest_id: '2')
  end
  
end

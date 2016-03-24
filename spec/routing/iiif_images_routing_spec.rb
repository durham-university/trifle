require "rails_helper"

RSpec.describe Trifle::IIIFImagesController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #show" do
    expect(get: "/iiif_images/1").to route_to("trifle/iiif_images#show", id: '1')
  end
  it "routes to #edit" do
    expect(get: "/iiif_images/1/edit").to route_to("trifle/iiif_images#edit", id: "1")
  end
  it "routes to #create" do
    expect(post: "/iiif_manifests/1/iiif_images").to route_to("trifle/iiif_images#create", iiif_manifest_id: "1")
  end
  it "routes to #new" do
    expect(get: "/iiif_manifests/1/iiif_images/new").to route_to("trifle/iiif_images#new", iiif_manifest_id: "1")
  end
  
  it "routes to #all_annotations" do
    expect(get: "/iiif_images/1/all_annotations").to route_to("trifle/iiif_images#all_annotations", id: "1")
  end

  it "routes to #update via PUT" do
    expect(put: "/iiif_images/1").to route_to("trifle/iiif_images#update", id: "1")
  end

  it "routes to #update via PATCH" do
    expect(patch: "/iiif_images/1").to route_to("trifle/iiif_images#update", id: "1")
  end

  it "routes to #destroy" do
    expect(delete: "/iiif_images/1").to route_to("trifle/iiif_images#destroy", id: "1")
  end
    
  it "routes to #show_iiif" do
    expect(get: "/iiif_images/1/iiif").to route_to("trifle/iiif_images#show_iiif", id: "1")
  end
  
end

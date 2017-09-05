require "rails_helper"

RSpec.describe Trifle::IIIFImagesController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #show" do
    expect(get: "/manifest/2/canvas/1").to route_to("trifle/iiif_images#show", id: '1', iiif_manifest_id: '2')
  end
  it "routes to #edit" do
    expect(get: "/manifest/2/canvas/1/edit").to route_to("trifle/iiif_images#edit", id: "1", iiif_manifest_id: '2')
  end
  it "routes to #create" do
    expect(post: "/manifest/1/canvas").to route_to("trifle/iiif_images#create", iiif_manifest_id: "1")
  end
  it "routes to #new" do
    expect(get: "/manifest/1/canvas/new").to route_to("trifle/iiif_images#new", iiif_manifest_id: "1")
  end
  
  it "routes to #all_annotations" do
    expect(get: "/manifest/2/canvas/1/all_annotations").to route_to("trifle/iiif_images#all_annotations", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #update via PUT" do
    expect(put: "/manifest/2/canvas/1").to route_to("trifle/iiif_images#update", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #update via PATCH" do
    expect(patch: "/manifest/2/canvas/1").to route_to("trifle/iiif_images#update", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #destroy" do
    expect(delete: "/manifest/2/canvas/1").to route_to("trifle/iiif_images#destroy", id: "1", iiif_manifest_id: '2')
  end
    
  it "routes to #show_iiif" do
    expect(get: "/iiif/manifest/2/canvas/1").to route_to("trifle/iiif_images#show_iiif", id: "1", iiif_manifest_id: '2')
  end
  
  it "routes to #show_annotation_iiif" do
    expect(get: "/iiif/manifest/2/annotation/canvas_1").to route_to("trifle/iiif_images#show_annotation_iiif", id: "1", iiif_manifest_id: '2')
  end
  
  it "routes to #refresh_from_source" do
    expect(post: "/manifest/2/canvas/1/refresh_from_source").to route_to("trifle/iiif_images#refresh_from_source", id: "1", iiif_manifest_id: '2')
  end
  
  it "routes to #link_millennium" do
    expect(post: "/canvas/1/link_millennium").to route_to("trifle/iiif_images#link_millennium", id: "1")
  end

end

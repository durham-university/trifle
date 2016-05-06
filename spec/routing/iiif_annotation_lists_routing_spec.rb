require "rails_helper"

RSpec.describe Trifle::IIIFAnnotationListsController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #show" do
    expect(get: "/manifest/2/list/1").to route_to("trifle/iiif_annotation_lists#show", id: '1', iiif_manifest_id: '2')
  end
  it "routes to #edit" do
    expect(get: "/manifest/2/list/1/edit").to route_to("trifle/iiif_annotation_lists#edit", id: "1", iiif_manifest_id: '2')
  end
  it "routes to #create" do
    expect(post: "/manifest/2/canvas/1/list").to route_to("trifle/iiif_annotation_lists#create", iiif_image_id: "1", iiif_manifest_id: '2')
  end
  it "routes to #new" do
    expect(get: "/manifest/2/canvas/1/list/new").to route_to("trifle/iiif_annotation_lists#new", iiif_image_id: "1", iiif_manifest_id: '2')
  end

  it "routes to #update via PUT" do
    expect(put: "/manifest/2/list/1").to route_to("trifle/iiif_annotation_lists#update", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #update via PATCH" do
    expect(patch: "/manifest/2/list/1").to route_to("trifle/iiif_annotation_lists#update", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #destroy" do
    expect(delete: "/manifest/2/list/1").to route_to("trifle/iiif_annotation_lists#destroy", id: "1", iiif_manifest_id: '2')
  end
    
  it "routes to #show_iiif" do
    expect(get: "/iiif/manifest/2/list/1").to route_to("trifle/iiif_annotation_lists#show_iiif", id: "1", iiif_manifest_id: '2')
  end
  
end

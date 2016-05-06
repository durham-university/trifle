require "rails_helper"

RSpec.describe Trifle::IIIFAnnotationsController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #show" do
    expect(get: "/manifest/2/annotation/1").to route_to("trifle/iiif_annotations#show", id: '1', iiif_manifest_id: '2')
  end
  it "routes to #edit" do
    expect(get: "/manifest/2/annotation/1/edit").to route_to("trifle/iiif_annotations#edit", id: "1", iiif_manifest_id: '2')
  end
  it "routes to #create" do
    expect(post: "/manifest/2/list/1/annotation").to route_to("trifle/iiif_annotations#create", iiif_annotation_list_id: "1", iiif_manifest_id: '2')
  end
  it "routes to #new" do
    expect(get: "/manifest/2/list/1/annotation/new").to route_to("trifle/iiif_annotations#new", iiif_annotation_list_id: "1", iiif_manifest_id: '2')
  end
  it "routes to #create from image" do
    expect(post: "/manifest/2/canvas/1/annotation").to route_to("trifle/iiif_annotations#create", iiif_image_id: "1", iiif_manifest_id: '2')
  end
  it "routes to #new from image" do
    expect(get: "/manifest/2/canvas/1/annotation/new").to route_to("trifle/iiif_annotations#new", iiif_image_id: "1", iiif_manifest_id: '2')
  end

  it "routes to #update via PUT" do
    expect(put: "/manifest/2/annotation/1").to route_to("trifle/iiif_annotations#update", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #update via PATCH" do
    expect(patch: "/manifest/2/annotation/1").to route_to("trifle/iiif_annotations#update", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #destroy" do
    expect(delete: "/manifest/2/annotation/1").to route_to("trifle/iiif_annotations#destroy", id: "1", iiif_manifest_id: '2')
  end
    
  it "routes to #show_iiif" do
    expect(get: "/iiif/manifest/2/annotation/1").to route_to("trifle/iiif_annotations#show_iiif", id: "1", iiif_manifest_id: '2')
  end
  
end

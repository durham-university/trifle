require "rails_helper"

RSpec.describe Trifle::IIIFAnnotationsController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #show" do
    expect(get: "/iiif_annotations/1").to route_to("trifle/iiif_annotations#show", id: '1')
  end
  it "routes to #edit" do
    expect(get: "/iiif_annotations/1/edit").to route_to("trifle/iiif_annotations#edit", id: "1")
  end
  it "routes to #create" do
    expect(post: "/iiif_annotation_lists/1/iiif_annotations").to route_to("trifle/iiif_annotations#create", iiif_annotation_list_id: "1")
  end
  it "routes to #new" do
    expect(get: "/iiif_annotation_lists/1/iiif_annotations/new").to route_to("trifle/iiif_annotations#new", iiif_annotation_list_id: "1")
  end
  it "routes to #create from image" do
    expect(post: "/iiif_images/1/iiif_annotations").to route_to("trifle/iiif_annotations#create", iiif_image_id: "1")
  end
  it "routes to #new from image" do
    expect(get: "/iiif_images/1/iiif_annotations/new").to route_to("trifle/iiif_annotations#new", iiif_image_id: "1")
  end

  it "routes to #update via PUT" do
    expect(put: "/iiif_annotations/1").to route_to("trifle/iiif_annotations#update", id: "1")
  end

  it "routes to #update via PATCH" do
    expect(patch: "/iiif_annotations/1").to route_to("trifle/iiif_annotations#update", id: "1")
  end

  it "routes to #destroy" do
    expect(delete: "/iiif_annotations/1").to route_to("trifle/iiif_annotations#destroy", id: "1")
  end
    
  it "routes to #show_iiif" do
    expect(get: "/iiif_annotations/1/iiif").to route_to("trifle/iiif_annotations#show_iiif", id: "1")
  end
  
end

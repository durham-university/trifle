require "rails_helper"

RSpec.describe Trifle::IIIFRangesController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #show" do
    expect(get: "/manifest/2/range/1").to route_to("trifle/iiif_ranges#show", id: '1', iiif_manifest_id: '2')
  end
  it "routes to #edit" do
    expect(get: "/manifest/2/range/1/edit").to route_to("trifle/iiif_ranges#edit", id: "1", iiif_manifest_id: '2')
  end
  it "routes to #create from manifest" do
    expect(post: "/manifest/1/range").to route_to("trifle/iiif_ranges#create", iiif_manifest_id: "1")
  end
  it "routes to #new from manifest" do
    expect(get: "/manifest/1/range/new").to route_to("trifle/iiif_ranges#new", iiif_manifest_id: "1")
  end
  it "routes to #create from range" do
    expect(post: "/manifest/2/range/1/range").to route_to("trifle/iiif_ranges#create", iiif_range_id: "1", iiif_manifest_id: '2')
  end
  it "routes to #new from range" do
    expect(get: "/manifest/2/range/1/range/new").to route_to("trifle/iiif_ranges#new", iiif_range_id: "1", iiif_manifest_id: '2')
  end

  it "routes to #update via PUT" do
    expect(put: "/manifest/2/range/1").to route_to("trifle/iiif_ranges#update", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #update via PATCH" do
    expect(patch: "/manifest/2/range/1").to route_to("trifle/iiif_ranges#update", id: "1", iiif_manifest_id: '2')
  end

  it "routes to #destroy" do
    expect(delete: "/manifest/2/range/1").to route_to("trifle/iiif_ranges#destroy", id: "1", iiif_manifest_id: '2')
  end
    
  it "routes to #show_iiif" do
    expect(get: "/iiif/manifest/2/range/1").to route_to("trifle/iiif_ranges#show_iiif", id: "1", iiif_manifest_id: '2')
  end
  
end

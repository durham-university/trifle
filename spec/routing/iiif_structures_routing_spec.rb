require "rails_helper"

RSpec.describe Trifle::IIIFStructuresController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #show" do
    expect(get: "/iiif_structures/1").to route_to("trifle/iiif_structures#show", id: '1')
  end
  it "routes to #edit" do
    expect(get: "/iiif_structures/1/edit").to route_to("trifle/iiif_structures#edit", id: "1")
  end
  it "routes to #create from manifest" do
    expect(post: "/iiif_manifests/1/iiif_structures").to route_to("trifle/iiif_structures#create", iiif_manifest_id: "1")
  end
  it "routes to #new from manifest" do
    expect(get: "/iiif_manifests/1/iiif_structures/new").to route_to("trifle/iiif_structures#new", iiif_manifest_id: "1")
  end
  it "routes to #create from structure" do
    expect(post: "/iiif_structures/1/iiif_structures").to route_to("trifle/iiif_structures#create", iiif_structure_id: "1")
  end
  it "routes to #new from structure" do
    expect(get: "/iiif_structures/1/iiif_structures/new").to route_to("trifle/iiif_structures#new", iiif_structure_id: "1")
  end

  it "routes to #update via PUT" do
    expect(put: "/iiif_structures/1").to route_to("trifle/iiif_structures#update", id: "1")
  end

  it "routes to #update via PATCH" do
    expect(patch: "/iiif_structures/1").to route_to("trifle/iiif_structures#update", id: "1")
  end

  it "routes to #destroy" do
    expect(delete: "/iiif_structures/1").to route_to("trifle/iiif_structures#destroy", id: "1")
  end
    
  it "routes to #show_iiif" do
    expect(get: "/iiif_structures/1/iiif").to route_to("trifle/iiif_structures#show_iiif", id: "1")
  end
  
end

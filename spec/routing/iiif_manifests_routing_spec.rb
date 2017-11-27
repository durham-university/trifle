require "rails_helper"

RSpec.describe Trifle::IIIFManifestsController, type: :routing do
  routes { Trifle::Engine.routes }

  it "routes to #index" do
    expect(get: "/manifest").to route_to("trifle/iiif_manifests#index")
  end
  it "routes to #show" do
    expect(get: "/manifest/1").to route_to("trifle/iiif_manifests#show", id: '1')
  end
  it "routes _/manifest to #show" do
    expect(get: "/manifest/1/manifest").to route_to("trifle/iiif_manifests#show", id: '1')
  end
  it "routes to #edit" do
    expect(get: "/manifest/1/edit").to route_to("trifle/iiif_manifests#edit", id: "1")
  end
  it "routes to #create" do
    expect(post: "/collection/1/manifest").to route_to("trifle/iiif_manifests#create", iiif_collection_id: "1")
  end
  it "routes to #new" do
    expect(get: "/collection/1/manifest/new").to route_to("trifle/iiif_manifests#new", iiif_collection_id: "1")
  end

  it "routes to #update via PUT" do
    expect(put: "/manifest/1").to route_to("trifle/iiif_manifests#update", id: "1")
  end

  it "routes to #update via PATCH" do
    expect(patch: "/manifest/1").to route_to("trifle/iiif_manifests#update", id: "1")
  end

  it "routes to #destroy" do
    expect(delete: "/manifest/1").to route_to("trifle/iiif_manifests#destroy", id: "1")
  end
  
  it "routes to #deposit_image via POST" do
    expect(post: "/manifest/1/deposit").to route_to("trifle/iiif_manifests#deposit_images", id: "1")
  end
  
  it "routes to #create_and_deposit_images via POST" do
    expect(post: "/collection/1/manifest/deposit").to route_to("trifle/iiif_manifests#create_and_deposit_images", iiif_collection_id: '1')
  end
  
  it "routes to #show_iiif" do
    expect(get: "/iiif/manifest/1").to route_to("trifle/iiif_manifests#show_iiif", id: "1")
  end
  
  it "routes to #show_sequence_iiif" do
    expect(get: "/iiif/manifest/1/sequence/default").to route_to("trifle/iiif_manifests#show_sequence_iiif", id: "1", sequence_name: 'default')
  end
  
  it "routes _/manifest to #show_iiif" do
    expect(get: "/iiif/manifest/1/manifest").to route_to("trifle/iiif_manifests#show_iiif", id: "1")
  end

  it "routes to #refresh_from_source via POST" do
    expect(post: "/manifest/1/refresh_from_source").to route_to("trifle/iiif_manifests#refresh_from_source", id: "1")
  end  
  
  it "routes to #publish via POST" do
    expect(post: "/manifest/1/publish").to route_to("trifle/iiif_manifests#publish", id: "1")
  end  
  
  it "routes to #update_ranges via POST" do
    expect(post: "/manifest/1/update_ranges").to route_to("trifle/iiif_manifests#update_ranges", id: "1")
  end  
  
  it "routes to #link_millennium via POST" do
    expect(post: "/manifest/1/link_millennium").to route_to("trifle/iiif_manifests#link_millennium", id: "1")
  end  

  it "routes to #repair_with_oubliette via POST" do
    expect(post: "/manifest/1/repair_with_oubliette").to route_to("trifle/iiif_manifests#repair_with_oubliette", id: "1")
  end    
end
